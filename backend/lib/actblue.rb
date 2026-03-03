require "digest"

module ActBlue
  def self.idempotency_key(order_number, paid_at, line_item_id)
    Digest::SHA256.hexdigest("#{order_number}:#{paid_at}:#{line_item_id}")
  end
end