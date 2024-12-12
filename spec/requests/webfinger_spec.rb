require 'rails_helper'

RSpec.describe '/.well-known/webfinger', type: :request do
  context "when params[:resource] is blank" do
    it 'should return 404' do
      get '/.well-known/webfinger'

      expect(response).to have_http_status 404
    end
  end

  context "when params[:resource] is wrong" do
    it "should return 404" do
      get '/.well-known/webfinger?resource=acct:wrong@example.com'

      expect(response).to have_http_status 404
    end
  end

  context "when params[:resource] is present" do
    it 'should return 200' do
      get '/.well-known/webfinger?resource=acct:relay@example.com'

      expect(response).to have_http_status 200
    end
  end
end
