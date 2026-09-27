#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds App Store Connect users to the app's internal TestFlight group, once
# they have accepted their invitation to the team:
#
#     ruby scripts/testflight-testers.rb someone@example.com ...
#     ruby scripts/testflight-testers.rb --wait someone@example.com ...
#
# Internal testers must be members of the team first; an invitation not
# yet accepted is reported, not guessed at. --wait checks again every five
# minutes until everyone named is in (or two days pass). Uses the App
# Store Connect key from secrets/appstore.env, as testflight-notes.rb does,
# and prints nothing of it.

require 'json'
require 'net/http'
require 'openssl'
require 'base64'
require 'uri'

HERE = File.expand_path('..', __dir__)

def env_from_secrets
  file = File.join(HERE, 'secrets', 'appstore.env')
  return {} unless File.exist?(file)
  File.readlines(file).each_with_object({}) do |line, out|
    next unless (m = line.match(/^\s*([A-Z_]+)\s*=\s*(.+?)\s*$/))
    out[m[1]] = m[2].delete('"\'')
  end
end

secrets = env_from_secrets
KEY_ID = ENV['ASC_KEY_ID'] || secrets['ASC_KEY_ID']
ISSUER = ENV['ASC_ISSUER_ID'] || secrets['ASC_ISSUER_ID']
KEY_PATH = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{KEY_ID}.p8")

abort('No ASC_KEY_ID / ASC_ISSUER_ID; see secrets/appstore.env.') if KEY_ID.nil? || ISSUER.nil?
abort("No private key at #{KEY_PATH}.") unless File.exist?(KEY_PATH)

def b64(data)
  Base64.urlsafe_encode64(data).delete('=')
end

def token
  header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' }
  claims = { iss: ISSUER, iat: Time.now.to_i, exp: Time.now.to_i + 600,
             aud: 'appstoreconnect-v1' }
  signing = "#{b64(JSON.dump(header))}.#{b64(JSON.dump(claims))}"
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  der = key.sign(OpenSSL::Digest.new('SHA256'), signing)
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
  "#{signing}.#{b64(r + s)}"
end

def call(method, path, payload = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = {
    get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch
  }.fetch(method).new(uri)
  request['Authorization'] = "Bearer #{token}"
  if payload
    request['Content-Type'] = 'application/json'
    request.body = JSON.dump(payload)
  end
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(request) }
  body = begin
    JSON.parse(response.body)
  rescue StandardError
    { 'raw' => response.body }
  end
  [response.code, body]
end

BUNDLE_ID = 'io.github.johancarlstedt.family'

def app_id
  code, body = call(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")
  abort("Apps: HTTP #{code}") unless code == '200'
  body['data'].first&.dig('id') || abort("No app with bundle id #{BUNDLE_ID}")
end

def internal_group(app)
  code, body = call(:get, "/v1/apps/#{app}/betaGroups?limit=50")
  abort("Beta groups: HTTP #{code}") unless code == '200'
  group = body['data'].find { |g| g.dig('attributes', 'isInternalGroup') }
  group || abort('The app has no internal TestFlight group yet.')
end

def enc(value)
  URI.encode_www_form_component(value)
end

# :added, :already, :invited (not accepted yet), :unknown
def add(email, app, group)
  _, testers = call(:get, "/v1/betaTesters?filter[email]=#{enc(email)}&filter[apps]=#{app}&include=betaGroups")
  if (tester = testers['data']&.first)
    groups = tester.dig('relationships', 'betaGroups', 'data') || []
    return :already if groups.any? { |g| g['id'] == group['id'] }
  end
  _, users = call(:get, "/v1/users?filter[username]=#{enc(email)}")
  if users['data'].nil? || users['data'].empty?
    _, invites = call(:get, "/v1/userInvitations?filter[email]=#{enc(email)}")
    return invites['data']&.any? ? :invited : :unknown
  end
  user = users['data'].first['attributes']
  code, body = call(:post, '/v1/betaTesters', {
    data: {
      type: 'betaTesters',
      attributes: { email: email, firstName: user['firstName'], lastName: user['lastName'] },
      relationships: { betaGroups: { data: [{ type: 'betaGroups', id: group['id'] }] } }
    }
  })
  return :added if code.start_with?('2')

  errors = (body['errors'] || []).map { |e| e['detail'] || e['title'] }.join('; ')
  warn("#{email}: HTTP #{code} #{errors}")
  :failed
end

wait = ARGV.delete('--wait')
emails = ARGV.map(&:strip).reject(&:empty?)
abort('Usage: testflight-testers.rb [--wait] email ...') if emails.empty?

app = app_id
group = internal_group(app)
puts "Internal group: #{group.dig('attributes', 'name')}"
left = emails.dup
deadline = Time.now + 2 * 24 * 3600
loop do
  left.dup.each do |email|
    result = add(email, app, group)
    puts "#{Time.now.strftime('%H:%M')} #{email}: #{result}"
    left.delete(email) if %i[added already].include?(result)
  end
  break if left.empty? || !wait || Time.now > deadline

  sleep 300
end
exit(left.empty? ? 0 : 1)
