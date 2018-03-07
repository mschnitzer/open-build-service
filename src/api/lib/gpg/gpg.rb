module GPG
  def self.encrypt_by_fingerprint(fingerprint, data)
    Cheetah.run 'gpg', '--homedir', PublicKey.gpg_dir, '--encrypt', '--armor', '--trust-model', 'always', '--recipient', \
      fingerprint, stdin: data, stdout: :capture
  end

  module PublicKey
    def self.cloud_upload
      public_key = Nokogiri::XML(Backend::Api::Cloud.public_key(view: :info))
      fingerprint = public_key.children.first.attributes['fingerprint'].to_s.gsub(' ', '')

      import(public_key.children.first.children.to_s) unless in_keyring?(fingerprint)
      fingerprint
    end

    def self.in_keyring?(fingerprint)
      begin
        Cheetah.run 'gpg', '--homedir', gpg_dir, '--list-keys', fingerprint, stdout: :capture, stderr: :capture
      rescue Cheetah::ExecutionFailed => e
        return false if e.stderr =~ /error reading key\: No public key/

        # uh... it seems there is a different error occurring!
        raise e.stderr
      end

      true
    end

    def self.import(public_key)
      tmp_file_path = Rails.root.join('tmp', "gpg_public_key_#{rand(1000..999999999)}")

      begin
        File.open(tmp_file_path.to_s, 'w+') do |file|
          file.write(public_key)
        end

        Cheetah.run 'gpg', '--homedir', gpg_dir, '--import', stdin: File.open(tmp_file_path).read
      ensure
        FileUtils.rm(tmp_file_path) if File.exists?(tmp_file_path)
      end
    end

    def self.gpg_dir
      Rails.root.join('.gnupg').to_s
    end
  end
end
