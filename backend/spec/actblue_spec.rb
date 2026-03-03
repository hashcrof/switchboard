require "spec_helper"
require_relative "../lib/actblue"

RSpec.describe ActBlue do
  describe ".idempotency_key" do
    it "returns same hash key for same inputs" do
      resultA = ActBlue.idempotency_key("a", "b", "c")
      resultB = ActBlue.idempotency_key("a", "b", "c")
      expect(resultA).to eq(resultB)
    end

    it "returns different hash key for different inputs" do
      resultA = ActBlue.idempotency_key("a", "b", "c")
      resultB = ActBlue.idempotency_key("d", "e", "f")
      expect(resultA).not_to eq(resultB)
    end
  end
end