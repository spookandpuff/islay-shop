class SkuStockLog < ActiveRecord::Base
  include SkuDescription

  belongs_to :sku
  has_one :product, through: :sku

  track_user_edits

  action_log_url_params :product
  action_log_description :description

  # Returns a scope with calculated fields for who created the log and also,
  # all the fields necessary to summarize a SKU.
  #
  # @return ActiveRecord::Relation
  def self.summary
    select(%{
      sku_id, before, after, action, sku_stock_logs.created_at,
      (SELECT short_desc FROM skus WHERE skus.id = sku_id) AS short_desc,
      CASE
        WHEN sku_stock_logs.creator_id IS NULL then 'Customer'
        ELSE (SELECT name FROM users WHERE id = sku_stock_logs.creator_id)
      END AS creator_name
    })
  end

  # How much stock was added or removed.
  #
  # @return Integer
  def movement
    if before > after
      before - after
    else
      after - before
    end
  end

  # Which direction the stock level moved in; up/down.
  #
  # @return String
  def direction
    if before.blank?
      'set'
    elsif after.blank?
      'clear'
    elsif before > after
      'down'
    else
      'up'
    end
  end

  def description
    move = if before.blank?
      "Set stock to #{movement}"
    elsif after.blank?
      "Cleared stock"
    elsif before > after
      "Decreased stock by #{movement}"
    else
      "Increased stock by #{movement}"
    end

    "#{move} on #{sku.long_desc}"
  end
end
