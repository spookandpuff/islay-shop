class PromotionProductQuantityCondition < PromotionCondition
  desc  "Quantity of Product"

  metadata(:config) do
    foreign_key   :product_id,  :required => true, :values => lambda {Product.all.map {|s| [s.name, s.id]} }
    integer       :quantity,    :required => true, :greater_than => 0
  end

  def qualifies?
    false
  end
end
