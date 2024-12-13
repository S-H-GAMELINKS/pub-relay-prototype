require 'rails_helper'

RSpec.describe '/', type: :request do
  it 'should return 200' do
    get '/'

    expect(response).to have_http_status 200
  end

  it 'should response include /inbox path' do
    get '/'

    expect(response.body).to include('/inbox')
  end
end
