#!/usr/bin/env ruby
# Sets the "what to test" note testers see in TestFlight.
#
#   scripts/testflight-notes.rb <build-number> [notes.json]
#
# The notes file is one entry per App Store locale:
#
#   { "en-GB": "…", "sv": "…" }
#
# Defaults to release-notes/<build>.json. Without one, this does nothing
# and says so — a build with no note is worth shipping, a wrong note is
# not.
#
# Credentials: ASC_KEY_ID and ASC_ISSUER_ID from secrets/appstore.env, the
# same two the upload uses. The .p8 itself stays in
# ~/.appstoreconnect/private_keys and is read only to sign with; nothing
# here prints key material.
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

def why(body)
  (body['errors'] || []).map { |e| "#{e['code']}: #{e['detail']}" }.join(' | ')
end

build_number = ARGV[0] or abort('Usage: testflight-notes.rb <build> [notes.json]')
notes_file = ARGV[1] || File.join(HERE, 'release-notes', "#{build_number}.json")
unless File.exist?(notes_file)
  puts "No notes at #{notes_file}; leaving build #{build_number} without one."
  exit 0
end
# Explicit UTF-8: with no LANG set — which is how this runs from
# ios-testflight.sh rather than from a terminal — Ruby reads the file as
# US-ASCII and an em dash is enough to lose the whole note.
notes = JSON.parse(File.read(notes_file, encoding: 'UTF-8'))

# The build object exists only once Apple has ingested the upload, which
# takes minutes. Waiting here is the difference between notes that are
# there when the first tester looks and notes nobody sees.
build = nil
40.times do |attempt|
  code, body = call(:get, '/v1/builds?limit=20&sort=-uploadedDate')
  abort("#{code} asking for builds: #{why(body)}") unless code == '200'
  build = body['data'].find { |b| b['attributes']['version'] == build_number }
  break if build
  puts "Build #{build_number} is not with App Store Connect yet; waiting." if attempt.zero?
  sleep 30
end
abort("Build #{build_number} never appeared.") if build.nil?

code, body = call(:get, "/v1/builds/#{build['id']}/betaBuildLocalizations")
abort("#{code} reading notes: #{why(body)}") unless code == '200'
existing = body['data']

notes.each do |locale, text|
  have = existing.find { |l| l['attributes']['locale'] == locale }
  code, body = if have
    call(:patch, "/v1/betaBuildLocalizations/#{have['id']}", {
      'data' => { 'type' => 'betaBuildLocalizations', 'id' => have['id'],
                  'attributes' => { 'whatsNew' => text } }
    })
  else
    call(:post, '/v1/betaBuildLocalizations', {
      'data' => { 'type' => 'betaBuildLocalizations',
                  'attributes' => { 'locale' => locale, 'whatsNew' => text },
                  'relationships' => {
                    'build' => { 'data' => { 'type' => 'builds', 'id' => build['id'] } }
                  } }
    })
  end
  puts %w[200 201].include?(code) ? "#{locale}: set" : "#{locale}: HTTP #{code} #{why(body)}"
end
