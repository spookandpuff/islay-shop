class Promotion < ActiveRecord::Base
  has_many :orders
  has_many :order_items
  has_many :conditions, :class_name => 'PromotionCondition', :order => 'type ASC'
  has_one  :effect,     :class_name => 'PromotionEffect'

  attr_accessible :name, :start_at, :end_at, :conditions_attributes, :effect_attributes

  accepts_nested_attributes_for :conditions, :reject_if => :condition_inactive?

  before_save :clean_conditions

  def active?
    now = Time.now
    start_at <= now and (end_at.nil? || end_at >= now)
  end

  # Derives a description of the promotion by looking at the conditions and the
  # effect.
  def summary

  end

  def qualifies?(order)
    conditions.map {|c| c.qualifies?(order)}.all?
  end

  def apply!(order)
    effect.apply!(order)
  end

  def prefill
    types = conditions.map(&:type)
    PromotionCondition.definitions.each do |klass|
      # conditions << klass.new unless types.include?(klass.to_s)
      conditions.build(:type => klass.to_s) unless types.include?(klass.to_s)
    end
  end

  private

  def condition_inactive?(param)
    param[:active] == '0'
  end

  def clean_conditions
    conditions.each do |condition|
      condition.destroy unless condition.active
    end
  end
end
