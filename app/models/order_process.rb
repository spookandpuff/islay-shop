class OrderProcess < Order
  before_create :store_reference

  private

  def process_add!
    skus = Hash[items.map {|i| [i.sku_id, i.quantity]}]
    Sku.purchase_stock!(skus)
    next!
  end

  # Captures the funds that were previously authorized.
  #
  # @return Boolean
  def process_billing!
    if credit_card_payment.capture!
      next!("Captured #{formatted_total}")
    else
      fail!
    end
  end

  # Cancels an order. This will release authorization or credit payments, then
  # return all the SKUs from the order back into stock.
  #
  # @return Boolean
  def process_cancellation!
    if credit_card_payment.authorized?
      return_stock
      next!("Funds were not captured; authorization must be allowed to expire")
    elsif credit_card_payment.captured? and credit_card_payment.credit!
      return_stock
      next!("Credited #{formatted_total}")
    else
      fail!
    end
  end

  # A helper which will return all the items in this order back into stock.
  #
  # @return Hash
  def return_stock
    skus = Hash[items.map {|i| [i.sku_id, i.quantity]}]
    Sku.return_stock!(skus)
  end

  def process_shipping!
    next!
  end

  # Attempts to generate a reference for the order. Since the reference needs to
  # be unique and is generated rather than being a serial value, we attempt to
  # generate it five times. On failure, we raise an error.
  #
  # @return String
  def store_reference
    5.times do
      self[:reference] = generate_reference
      return reference unless self.class.where(:reference => reference).first
    end

    raise "Could not generate unique reference for order"
  end

  # Generates a reference using the time, and a 6 char hex string.
  #
  # @return String
  def generate_reference
    "#{Time.now.strftime('%y%m')}-#{SecureRandom.hex(3).upcase}"
  end
end
