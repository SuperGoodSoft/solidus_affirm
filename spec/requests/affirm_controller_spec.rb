require 'spec_helper'

RSpec.describe Spree::AffirmController do
  let(:order) { create(:order_with_totals) }
  let(:checkout_token) { "FOOBAR123" }
  let(:payment_method) { create(:affirm_payment_gateway) }

  describe 'POST confirm' do
    context 'when the order_id is not valid' do
      it "will raise an AR RecordNotFound" do
        expect {
          post '/affirm/confirm', params: {
            checkout_token: checkout_token,
            payment_method_id: payment_method.id,
            order_id: nil,
            use_route: :spree
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when the checkout_token is missing' do
      it "will redirect to the order current checkout state path" do
        post '/affirm/confirm', params: {
          checkout_token: nil,
          payment_method_id: payment_method.id,
          order_id: order.id,
          use_route: :spree
        }
        expect(response).to redirect_to('/checkout/cart')
      end
    end

    context 'when the order is already completed' do
      let(:order) { create(:completed_order_with_totals) }

      it 'will redirect to the order detail page' do
        post '/affirm/confirm', params: {
          checkout_token: checkout_token,
          payment_method_id: payment_method.id,
          order_id: order.id,
          use_route: :spree
        }
        expect(response).to redirect_to("/orders/#{order.number}")
      end
    end

    context 'with valid data' do
      let(:order) { create(:order_with_totals, state: "payment") }
      let(:payment_method) do
        create(
          :affirm_payment_gateway,
          preferred_public_api_key: "XPSQ3CA7PLN7CJCK",
          preferred_private_api_key: "w9mxkQUryKjTYDqOfSvYTeTGoLIURKpU",
          preferred_test_mode: true
        )
      end
      let(:checkout_token) { "26VJRAAYE0MB0V25" }

      it "creates a payment" do
        expect {
          post '/affirm/confirm', params: {
            checkout_token: checkout_token,
            payment_method_id: payment_method.id,
            order_id: order.id,
            use_route: :spree
          }
        }.to change { order.payments.count }.from(0).to(1)
      end

      it "redirect to the confirm page" do
        post '/affirm/confirm', params: {
          checkout_token: checkout_token,
          payment_method_id: payment_method.id,
          order_id: order.id,
          use_route: :spree
        }
        expect(response).to redirect_to('/checkout/confirm')
      end

      it "sets the payment total to the order total" do
        post '/affirm/confirm', params: {
          checkout_token: checkout_token,
          payment_method_id: payment_method.id,
          order_id: order.id,
          use_route: :spree
        }
        expect(order.payments.last.amount).to eq(order.total)
      end

      it "moves the order to its next state" do
        expect {
          post '/affirm/confirm', params: {
            checkout_token: checkout_token,
            payment_method_id: payment_method.id,
            order_id: order.id,
            use_route: :spree
          }
        }.to change { order.reload.state }.from("payment").to("confirm")
      end

      context "the order is already in confirm state" do
        let(:order) { create(:order_with_totals, state: "confirm") }

        it "moves the order to its next state" do
          expect {
            post '/affirm/confirm', params: {
              checkout_token: checkout_token,
              payment_method_id: payment_method.id,
              order_id: order.id,
              use_route: :spree
            }
          }.not_to change { order.reload.state }
        end
      end
    end
  end

  describe 'GET cancel' do
    context "with an order_id present" do
      it "will redirect to the current order checkout state" do
        get '/affirm/cancel', params: {
          payment_method_id: payment_method.id,
          order_id: order.id,
          use_route: :spree
        }
        expect(response).to redirect_to('/checkout/cart')
      end
    end
  end
end
