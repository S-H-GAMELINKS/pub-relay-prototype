module SignatureVerification
  extend ActiveSupport::Concern

  def signed_request?
    request.headers['Signature'].present?
  end

  def signature_verification_failure_reason
    return @signature_verification_failure_reason if defined?(@signature_verification_failure_reason)
  end

  def signed_request_account
    return @signed_request_account if defined?(@signed_request_account)

    unless signed_request?
      @signature_verification_failure_reason = 'Request not signed'
      @signed_request_account = nil
      return
    end

    raw_signature    = request.headers['Signature']
    signature_params = {}

    raw_signature.split(',').each do |part|
      parsed_parts = part.match(/([a-z]+)="([^"]+)"/i)
      next if parsed_parts.nil? || parsed_parts.size != 3
      signature_params[parsed_parts[1]] = parsed_parts[2]
    end

    if incompatible_signature?(signature_params)
      @signature_verification_failure_reason = 'Incompatible request signature'
      @signed_request_account = nil
      return
    end

    account = account_from_key_id(signature_params['keyId'])

    if account.nil?
      @signature_verification_failure_reason = "Public key not found for key #{signature_params['keyId']}"
      @signed_request_account = nil
      return
    end

    signature             = Base64.decode64(signature_params['signature'])
    compare_signed_string = build_signed_string(signature_params['headers'])

    if key_from_account(account).verify(OpenSSL::Digest::SHA256.new, signature, compare_signed_string)
      @signed_request_account = account
      @signed_request_account
    elsif account.possibly_stale?
      account = account.refresh!

      if account.keypair.public_key.verify(OpenSSL::Digest::SHA256.new, signature, compare_signed_string)
        @signed_request_account = account
        @signed_request_account
      else
        @signature_verification_failure_reason = "Verification failed for #{signature_params['keyId']}"
        @signed_request_account = nil
      end
    else
      @signature_verification_failure_reason = "Verification failed for #{signature_params['keyId']}"
      @signed_request_account = nil
    end
  end

  def request_body
    @request_body ||= request.raw_post
  end

  private

  def build_signed_string(signed_headers)
    signed_headers = 'date' if signed_headers.blank?

    signed_headers.split(' ').map do |signed_header|
      if signed_header == '(request-target)'
        "(request-target): #{request.method.downcase} #{request.path}"
      elsif signed_header == 'digest'
        "digest: #{body_digest}"
      else
        "#{signed_header}: #{request.headers[to_header_name(signed_header)]}"
      end
    end.join("\n")
  end

  def matches_time_window?
    begin
      time_sent = DateTime.httpdate(request.headers['Date'])
    rescue ArgumentError
      return false
    end

    (Time.now.utc - time_sent).abs <= 30
  end

  def body_digest
    "SHA-256=#{Digest::SHA256.base64digest(request_body)}"
  end

  def to_header_name(name)
    name.split(/-/).map(&:capitalize).join('-')
  end

  def incompatible_signature?(signature_params)
    signature_params['keyId'].blank? ||
      signature_params['signature'].blank?
  end

  def optional_fetch(url)
    Oj.load(Rails.cache.fetch(url, raw: true, expires_in: 1.day) {
      HTTP.headers('Accept' => 'application/activity+json, application/ld+json')
          .get(url)
          .to_s
    }, mode: :null)
  end

  def account_from_key_id(key_id)
    json = optional_fetch(key_id)

    if json['publicKeyPem']
      actor = optional_fetch(json['owner'])
      actor['publicKey'] = json
      actor
    else
      json
    end
  end

  def key_from_account(account)
    OpenSSL::PKey::RSA.new(account['publicKey']['publicKeyPem'])
  end
end
