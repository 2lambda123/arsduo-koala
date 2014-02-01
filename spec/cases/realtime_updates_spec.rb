require 'spec_helper'
require 'base64'

describe "Koala::Facebook::RealtimeUpdates" do
  before :all do
    # get oauth data
    @app_id = KoalaTest.app_id
    @secret = KoalaTest.secret
    @callback_url = KoalaTest.oauth_test_data["callback_url"]
    @app_access_token = KoalaTest.app_access_token

    # check OAuth data
    unless @app_id && @secret && @callback_url && @app_access_token
      raise Exception, "Must supply OAuth app id, secret, app_access_token, and callback to run live subscription tests!"
    end

    # get subscription data
    @verify_token = KoalaTest.subscription_test_data["verify_token"]
    @challenge_data = KoalaTest.subscription_test_data["challenge_data"]
    @subscription_path = KoalaTest.subscription_test_data["subscription_path"]

    # check subscription data
    unless @verify_token && @challenge_data && @subscription_path
      raise Exception, "Must supply verify_token and equivalent challenge_data to run subscription tests!"
    end
  end

  before :each do
    @updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :secret => @secret)
  end

  describe ".new" do
    # basic initialization
    it "initializes properly with an app_id and an app_access_token" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :app_access_token => @app_access_token)
      expect(updates).to be_a(Koala::Facebook::RealtimeUpdates)
    end

    # attributes
    it "allows read access to app_id" do
      # in Ruby 1.9, .method returns symbols
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).to include(:app_id)
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).not_to include(:app_id=)
    end

    it "allows read access to app_access_token" do
      # in Ruby 1.9, .method returns symbols
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).to include(:app_access_token)
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).not_to include(:app_access_token=)
    end

    it "allows read access to secret" do
      # in Ruby 1.9, .method returns symbols
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).to include(:secret)
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).not_to include(:secret=)
    end

    it "allows read access to api" do
      # in Ruby 1.9, .method returns symbols
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).to include(:api)
      expect(Koala::Facebook::RealtimeUpdates.instance_methods.map(&:to_sym)).not_to include(:api=)
    end

    # old graph_api accessor
    it "returns the api object when graph_api is called" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :secret => @secret)
      expect(updates.graph_api).to eq(updates.api)
    end

    it "fire a deprecation warning when graph_api is called" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :secret => @secret)
      expect(Koala::Utils).to receive(:deprecate)
      updates.graph_api
    end

    # init with secret / fetching the token
    it "initializes properly with an app_id and a secret" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :secret => @secret)
      expect(updates).to be_a(Koala::Facebook::RealtimeUpdates)
    end

    it "fetches an app_token from Facebook when provided an app_id and a secret" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :secret => @secret)
      expect(updates.app_access_token).not_to be_nil
    end

    it "uses the OAuth class to fetch a token when provided an app_id and a secret" do
      oauth = Koala::Facebook::OAuth.new(@app_id, @secret)
      token = oauth.get_app_access_token
      expect(oauth).to receive(:get_app_access_token).and_return(token)
      expect(Koala::Facebook::OAuth).to receive(:new).with(@app_id, @secret).and_return(oauth)
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :secret => @secret)
    end

    it "sets up the with the app acces token" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :app_access_token => @app_access_token)
      expect(updates.api).to be_a(Koala::Facebook::API)
      expect(updates.api.access_token).to eq(@app_access_token)
    end

  end

  describe "#subscribe" do
    it "makes a POST to the subscription path" do
      expect(@updates.api).to receive(:graph_call).with(@updates.subscription_path, anything, "post", anything)
      @updates.subscribe("user", "name", @subscription_path, @verify_token)
    end

    it "properly formats the subscription request" do
      obj = "user"
      fields = "name"
      expect(@updates.api).to receive(:graph_call).with(anything, hash_including(
        :object => obj,
        :fields => fields,
        :callback_url => @subscription_path,
        :verify_token => @verify_token
      ), anything, anything)
      @updates.subscribe("user", "name", @subscription_path, @verify_token)
    end

    pending "doesn't require a verify_token" do
      # see https://github.com/arsduo/koala/issues/150
      obj = "user"
      fields = "name"
      expect(@updates.api).not_to receive(:graph_call).with(anything, hash_including(:verify_token => anything), anything, anything)
      @updates.subscribe("user", "name", @subscription_path)
    end

    it "requires verify_token" do
      expect { @updates.subscribe("user", "name", @subscription_path) }.to raise_exception
    end

    it "accepts an options hash" do
      options = {:a => 2, :b => "c"}
      expect(@updates.api).to receive(:graph_call).with(anything, anything, anything, hash_including(options))
      @updates.subscribe("user", "name", @subscription_path, @verify_token, options)
    end

    describe "in practice" do
      it "sends a subscription request" do
        expect { @updates.subscribe("user", "name", @subscription_path, @verify_token) }.to_not raise_error
      end

      pending "sends a subscription request without a verify token" do
        expect { @updates.subscribe("user", "name", @subscription_path) }.to_not raise_error
      end

      it "fails if you try to hit an invalid path on your valid server" do
        expect { result = @updates.subscribe("user", "name", @subscription_path + "foo", @verify_token) }.to raise_exception(Koala::Facebook::APIError)
      end

      it "fails to send a subscription request to an invalid server" do
        expect { @updates.subscribe("user", "name", "foo", @verify_token) }.to raise_exception(Koala::Facebook::APIError)
      end
    end
  end

  describe "#unsubscribe" do
    it "makes a DELETE to the subscription path" do
      expect(@updates.api).to receive(:graph_call).with(@updates.subscription_path, anything, "delete", anything)
      @updates.unsubscribe("user")
    end

    it "includes the object if provided" do
      obj = "user"
      expect(@updates.api).to receive(:graph_call).with(anything, hash_including(:object => obj), anything, anything)
      @updates.unsubscribe(obj)
    end

    it "accepts an options hash" do
      options = {:a => 2, :b => "C"}
      expect(@updates.api).to receive(:graph_call).with(anything, anything, anything, hash_including(options))
      @updates.unsubscribe("user", options)
    end

    describe "in practice" do
      it "unsubscribes a valid individual object successfully" do
        expect { @updates.unsubscribe("user") }.to_not raise_error
      end

      it "unsubscribes all subscriptions successfully" do
        expect { @updates.unsubscribe }.to_not raise_error
      end

      it "fails when an invalid object is provided to unsubscribe" do
        expect { @updates.unsubscribe("kittens") }.to raise_error(Koala::Facebook::APIError)
      end
    end
  end

  describe "#list_subscriptions" do
    it "GETs the subscription path" do
      expect(@updates.api).to receive(:graph_call).with(@updates.subscription_path, anything, "get", anything)
      @updates.list_subscriptions
    end

    it "accepts options" do
      options = {:a => 3, :b => "D"}
      expect(@updates.api).to receive(:graph_call).with(anything, anything, anything, hash_including(options))
      @updates.list_subscriptions(options)
    end

    describe "in practice" do
      it "lists subscriptions properly" do
        expect(@updates.list_subscriptions).to be_a(Array)
      end
    end
  end

  describe "#subscription_path" do
    it "returns the app_id/subscriptions" do
      expect(@updates.subscription_path).to eq("#{@app_id}/subscriptions")
    end
  end

  describe "#validate_update" do
    it "raises an error if no secret is defined" do
      updates = Koala::Facebook::RealtimeUpdates.new(:app_id => @app_id, :app_access_token => "foo")
      expect {
        updates.validate_update("", {})
      }.to raise_exception(Koala::Facebook::AppSecretNotDefinedError)
    end

    it "returns false if there is no X-Hub-Signature header" do
      expect(@updates.validate_update("", {})).to be_falsy
    end

    it "returns false if the signature doesn't match the body" do
      expect(@updates.validate_update("", {"X-Hub-Signature" => "sha1=badsha1"})).to be false
    end

    it "results true if the signature matches the body with the secret" do
      body = "BODY"
      signature = OpenSSL::HMAC.hexdigest('sha1', @secret, body).chomp
      expect(@updates.validate_update(body, {"X-Hub-Signature" => "sha1=#{signature}"})).to be true
    end

    it "results true with alternate HTTP_X_HUB_SIGNATURE header" do
      body = "BODY"
      signature = OpenSSL::HMAC.hexdigest('sha1', @secret, body).chomp
      expect(@updates.validate_update(body, {"HTTP_X_HUB_SIGNATURE" => "sha1=#{signature}"})).to be true
    end

  end

  describe ".meet_challenge" do
    it "returns false if hub.mode isn't subscribe" do
      params = {'hub.mode' => 'not subscribe'}
      expect(Koala::Facebook::RealtimeUpdates.meet_challenge(params)).to be false
    end

    it "doesn't evaluate the block if hub.mode isn't subscribe" do
      params = {'hub.mode' => 'not subscribe'}
      block_evaluated = false
      Koala::Facebook::RealtimeUpdates.meet_challenge(params){|token| block_evaluated = true}
      expect(block_evaluated).to be false
    end

    it "returns false if not given a verify_token or block" do
      params = {'hub.mode' => 'subscribe'}
      expect(Koala::Facebook::RealtimeUpdates.meet_challenge(params)).to be false
    end

    describe "and mode is 'subscribe'" do
      before(:each) do
        @params = {'hub.mode' => 'subscribe'}
      end

      describe "and a token is given" do
        before(:each) do
          @token = 'token'
          @params['hub.verify_token'] = @token
        end

        it "returns false if the given verify token doesn't match" do
          expect(Koala::Facebook::RealtimeUpdates.meet_challenge(@params, @token + '1')).to be false
        end

        it "returns the challenge if the given verify token matches" do
          @params['hub.challenge'] = 'challenge val'
          expect(Koala::Facebook::RealtimeUpdates.meet_challenge(@params, @token)).to eq(@params['hub.challenge'])
        end
      end

      describe "and a block is given" do
        before :each do
          @params['hub.verify_token'] = @token
        end

        it "gives the block the token as a parameter" do
          Koala::Facebook::RealtimeUpdates.meet_challenge(@params) do |token|
            expect(token).to eq(@token)
          end
        end

        it "returns false if the given block return false" do
          expect(Koala::Facebook::RealtimeUpdates.meet_challenge(@params) do |token|
            false
          end).to be false
        end

        it "returns false if the given block returns nil" do
          expect(Koala::Facebook::RealtimeUpdates.meet_challenge(@params) do |token|
            nil
          end).to be false
        end

        it "returns the challenge if the given block returns true" do
          @params['hub.challenge'] = 'challenge val'
          expect(Koala::Facebook::RealtimeUpdates.meet_challenge(@params) do |token|
            true
          end).to be_truthy
        end
      end
    end
  end
end
