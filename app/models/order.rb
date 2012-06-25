class Order < ActiveRecord::Base
  # Turn off single table inheritance
  self.inheritance_column = :_type_disabled
  self.table_name = 'orders'

  belongs_to  :person
  has_one     :credit_card_payment
  has_many    :items,            :class_name => 'OrderItem'
  has_many    :bonus_items,      :class_name => 'OrderBonusItem'
  has_many    :discount_items,   :class_name => 'OrderDiscountItem'

  # These are the only attributes that we want to expose publically.
  attr_accessible(
    :billing_country, :billing_postcode, :billing_state, :billing_street,
    :billing_city, :email, :gift_message, :gifted_to, :is_gift, :name, :phone,
    :shipping_city, :shipping_country, :shipping_instructions, :shipping_postcode,
    :shipping_state, :shipping_street, :use_shipping_address, :items_dump
  )

  # This association has an extra method attached to it. This is so we can
  # easily retrieve an item by it's sku_id, which is necessary for both
  # #add_item and #remove_item.
  #
  # It is implemented so it can handle the case the there items are in memory
  # only, or where they are persisted in the DB.
  has_many :regular_items, :class_name => 'OrderRegularItem' do
    def by_sku_id(sku_id)
      # We check for existance like this, since this catches records that have
      # both been loaded from the DB and new instances built on the assocation.
      if self[0]
        select {|i| i.sku_id == sku_id}.first
      else
        where(:sku_id => sku_id).first
      end
    end
  end

  accepts_nested_attributes_for :regular_items
  before_save :calculate_totals
  track_user_edits

  # Generates and order from a JSON object. The apply boolean indicates if
  # promotions should be applied to the order after it has been loaded.
  #
  # @param [String] json JSON representation of order (result of #dump)
  # @param [Boolean] apply apply promotions after loading
  #
  # @todo Investigate checking stock levels when loading to see if it has
  # been decremented by another action between requests.
  def self.load(json, apply = true)
    order = new(JSON.parse(json))
    order.apply_promotions if apply
    order
  end

  # Specifies the values that can be safely exposed to the public. This is used
  # by the #dump method to create a JSON string that can be written to session.
  DUMP_OPTS = {
    root: false, :methods => :items_dump,
    :except => [
      :id, :product_total, :shipping_total, :total, :currency,
      :creator_id, :updater_id, :created_at, :updated_at, :person_id
    ]
  }

  # Generates a JSON string representation of the order and it's items. It
  # only dumps the regular items and their quantities. Bonus and discount
  # details are ignored, since they are reapplied when the order is loaded.
  #
  # @return [String] JSON representation of order
  def dump
    to_json(DUMP_OPTS)
  end

  # This either returns the stored product total or it calculates it by summing
  # the totals from each regular and discounted line item.
  #
  # @return [Integer] total value of 'purchasable' items in order
  def product_total
    self[:product_total] ||= (regular_items.map(&:total) + discount_items.map(&:total)).sum
  end

  # Provides a simplified representation of the items in an order, consolidating
  # regular and discounted items into a single collection.
  #
  # It is intended to be used when dumping the order contents to JSON.
  #
  # @return [String] JSON representation of order items
  def items_dump
    regular   = regular_items.map   {|item| {:sku_id => item.sku_id, :quantity => item.quantity}}
    discount  = discount_items.map  {|item| {:sku_id => item.sku_id, :quantity => item.quantity}}

    regular + discount
  end

  # When loading up an order from session, this accessor is used to generate the
  # regular item instances on the order model.
  #
  # @params [Array<Hash>] raw values for order items
  def items_dump=(items)
    items.each {|i| regular_items.build(i)}
  end

  class PromotionApplyError < StandardError
    def to_s
      "This order has promotions applied to it. You cannot modify it without
       removing them first. Try calling #remove_promotions on the order first."
    end
  end

  def remove_promotions
    bonus_items.delete

    discount_items.each do |item|
      regular_items.build(:sku_id => item.sku_id, :quantity => item.quantity)
      discount_items.delete(item)
    end

    @_promotions_applied = false
  end

  def apply_promotions
    raise PromotionApplyError if @_promotions_applied

    Promotion.active.each {|p| p.apply!(self) if p.qualifies?(self)}
    @_promotions_applied = true
  end

  def calculate_totals
    self.total = product_total + shipping_total
  end
end
