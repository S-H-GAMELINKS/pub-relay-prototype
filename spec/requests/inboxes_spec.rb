require 'rails_helper'

RSpec.describe '/inbox', type: :request do
  describe 'POST /inbox' do
    context 'when not signed_request_account' do
      before do
        allow_any_instance_of(InboxesController).to receive(:signed_request_account).and_return(false)
      end

      it 'should return 401' do
        post '/inbox'

        expect(response).to have_http_status 401
      end
    end

    context 'when signed_request' do
      context 'when blocked domain' do
        before do
          allow_any_instance_of(InboxesController).to receive(:signed_request_account).and_return(true)
          allow_any_instance_of(InboxesController).to receive(:blocked?).and_return(true)
        end

        it 'should return 401' do
          post '/inbox'

          expect(response).to have_http_status 401
        end
      end

      context 'when not blocked domain' do
        before do
          allow_any_instance_of(InboxesController).to receive(:signed_request_account).and_return(true)
          allow_any_instance_of(InboxesController).to receive(:blocked?).and_return(false)
        end

        it 'should return 202' do
          post '/inbox'

          expect(response).to have_http_status 202
        end

        it 'should enqueued ProcessWorker' do
          expect(ProcessWorker).to receive(:perform_async)

          post '/inbox'
        end
      end
    end
  end
end
