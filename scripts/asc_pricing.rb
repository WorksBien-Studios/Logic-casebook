#!/usr/bin/env ruby

# Reconciles App Store Connect pricing with the repo's locked pricing:
#   - the app itself is free (Japan base territory);
#   - the non-consumable full unlock is a one-time JPY purchase.
# Defaults to a read-only dry run; set APPLY=true to write.

require "json"
require "net/http"
require "open3"
require "uri"

API = "https://api.appstoreconnect.apple.com"

def required_env(name)
  value = ENV[name].to_s.strip
  abort "Missing #{name}." if value.empty?
  value
end

KEY_PATH = required_env("ASC_KEY_PATH")
KEY_ID = required_env("ASC_KEY_ID")
ISSUER_ID = required_env("ASC_ISSUER_ID")
APP_ID = required_env("ASC_APP_ID")
BUNDLE_ID = required_env("IOS_BUNDLE_ID")
PRODUCT_ID = required_env("IAP_PRODUCT_ID")
IAP_PRICE = required_env("IAP_PRICE") # customer price in the base territory, e.g. "1800"
TERRITORY = ENV.fetch("BASE_TERRITORY", "JPN")
APPLY = ENV["APPLY"] == "true"
LOCALE = ENV.fetch("IAP_LOCALE", "ja")
DISPLAY_NAME = required_env("IAP_DISPLAY_NAME")
DESCRIPTION = required_env("IAP_DESCRIPTION")
REFERENCE_NAME = required_env("IAP_REFERENCE_NAME")

def token
  script = File.expand_path("asc_jwt.rb", __dir__)
  jwt, status = Open3.capture2("ruby", script, KEY_PATH, KEY_ID, ISSUER_ID)
  abort "JWT generation failed." unless status.success?
  jwt.strip
end

def request(method, path, body: nil)
  uri = path.start_with?("http") ? URI(path) : URI.join(API, path)
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json" if body
  req.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  return JSON.parse(response.body.to_s.empty? ? "{}" : response.body) if response.code.to_i.between?(200, 299)
  abort "App Store Connect #{method.to_s.upcase} #{uri.path} failed with HTTP #{response.code}: #{response.body}"
end

def get_all(path)
  items = []
  included = []
  next_url = path
  while next_url
    page = request(:get, next_url)
    items.concat(page.fetch("data", []))
    included.concat(page.fetch("included", []))
    next_url = page.dig("links", "next")
  end
  [items, included]
end

def price_point_for(points, price)
  matches = points.select { |p| p.fetch("attributes").fetch("customerPrice").to_f == price.to_f }
  abort "Expected exactly one #{TERRITORY} price point for #{price}; found #{matches.length}." unless matches.length == 1
  matches.first.fetch("id")
end

def change(description)
  puts "#{APPLY ? 'APPLY' : 'DRY-RUN'}: #{description}"
end

actual_bundle = request(:get, "/v1/apps/#{APP_ID}").dig("data", "attributes", "bundleId")
abort "Mapped app bundle mismatch." unless actual_bundle == BUNDLE_ID

# --- App: free ---------------------------------------------------------------
app_query = URI.encode_www_form("filter[territory]" => TERRITORY, "limit" => "200")
app_points, = get_all("/v1/apps/#{APP_ID}/appPricePoints?#{app_query}")
free_point = price_point_for(app_points, 0)
current_app, current_app_included = get_all("/v1/apps/#{APP_ID}/appPriceSchedule/manualPrices?include=appPricePoint&limit=50") rescue [[], []]
app_is_free = current_app.any? && current_app_included.any? { |i| i["type"] == "appPricePoints" && i["id"] == free_point }
if app_is_free
  puts "OK: app already free in #{TERRITORY}."
else
  change("set app price to free in #{TERRITORY}")
  if APPLY
    request(:post, "/v1/appPriceSchedules", body: {
      data: {
        type: "appPriceSchedules",
        relationships: {
          app: { data: { type: "apps", id: APP_ID } },
          baseTerritory: { data: { type: "territories", id: TERRITORY } },
          manualPrices: { data: [{ type: "appPrices", id: "${app-price}" }] }
        }
      },
      included: [{
        type: "appPrices",
        id: "${app-price}",
        attributes: { startDate: nil },
        relationships: { appPricePoint: { data: { type: "appPricePoints", id: free_point } } }
      }]
    })
  end
end

# --- In-app purchase: full unlock -------------------------------------------
lookup = URI.encode_www_form("filter[productId]" => PRODUCT_ID, "limit" => "2")
found, = get_all("/v1/apps/#{APP_ID}/inAppPurchasesV2?#{lookup}")
abort "Product lookup was ambiguous." if found.length > 1
iap_id = found.first&.fetch("id")

if iap_id
  type = found.first.dig("attributes", "inAppPurchaseType")
  abort "Existing #{PRODUCT_ID} is #{type}, expected NON_CONSUMABLE." unless type == "NON_CONSUMABLE"
  puts "OK: in-app purchase #{PRODUCT_ID} exists (#{iap_id})."
else
  change("create NON_CONSUMABLE in-app purchase #{PRODUCT_ID}")
  if APPLY
    created = request(:post, "/v2/inAppPurchases", body: {
      data: {
        type: "inAppPurchases",
        attributes: {
          name: REFERENCE_NAME,
          productId: PRODUCT_ID,
          inAppPurchaseType: "NON_CONSUMABLE",
          familySharable: false
        },
        relationships: { app: { data: { type: "apps", id: APP_ID } } }
      }
    })
    iap_id = created.dig("data", "id")
  end
end

if iap_id
  locales, = get_all("/v2/inAppPurchases/#{iap_id}/inAppPurchaseLocalizations?limit=50")
  if locales.any? { |l| l.dig("attributes", "locale") == LOCALE }
    puts "OK: #{LOCALE} localization exists."
  else
    change("add #{LOCALE} localization \"#{DISPLAY_NAME}\"")
    if APPLY
      request(:post, "/v1/inAppPurchaseLocalizations", body: {
        data: {
          type: "inAppPurchaseLocalizations",
          attributes: { locale: LOCALE, name: DISPLAY_NAME, description: DESCRIPTION },
          relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap_id } } }
        }
      })
    end
  end

  iap_query = URI.encode_www_form("filter[territory]" => TERRITORY, "limit" => "200")
  iap_points, = get_all("/v2/inAppPurchases/#{iap_id}/pricePoints?#{iap_query}")
  target_point = price_point_for(iap_points, IAP_PRICE)
  _prices, included = get_all("/v2/inAppPurchases/#{iap_id}/iapPriceSchedule/manualPrices?include=inAppPricePoint&limit=50") rescue [[], []]
  if included.any? { |i| i["type"] == "inAppPurchasePricePoints" && i["id"] == target_point }
    puts "OK: #{PRODUCT_ID} already priced at #{IAP_PRICE} in #{TERRITORY}."
  else
    change("set #{PRODUCT_ID} to #{IAP_PRICE} in #{TERRITORY}")
    if APPLY
      request(:post, "/v1/inAppPurchasePriceSchedules", body: {
        data: {
          type: "inAppPurchasePriceSchedules",
          relationships: {
            inAppPurchase: { data: { type: "inAppPurchases", id: iap_id } },
            baseTerritory: { data: { type: "territories", id: TERRITORY } },
            manualPrices: { data: [{ type: "inAppPurchasePrices", id: "${iap-price}" }] }
          }
        },
        included: [{
          type: "inAppPurchasePrices",
          id: "${iap-price}",
          attributes: { startDate: nil },
          relationships: { inAppPurchasePricePoint: { data: { type: "inAppPurchasePricePoints", id: target_point } } }
        }]
      })
    end
  end
else
  puts "DRY-RUN: in-app purchase does not exist yet; localization and price checks skipped."
end

puts JSON.generate({ app_id: APP_ID, product_id: PRODUCT_ID, territory: TERRITORY, iap_price: IAP_PRICE, applied: APPLY })
