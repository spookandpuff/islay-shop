module SkuDescription
  # Summary of this SKU, which includes it's product name, data cols, sizing,
  # price etc.
  #
  # @return String
  #
  # @note This should be over-ridden in any subclasses to be more specific.
  def short_desc
    [].tap do |o|
      o << name if name?
      o << formatted_weight if weight?
      o << formatted_volume if volume?
      o << size if size?
    end.join(', ')
  end

  # Formats the weight into either string displaying either kilograms or grams.
  #
  # @return String
  def formatted_weight
    if weight >= 1000
      "#{weight / 100}kg"
    else
      "#{weight}g"
    end
  end

  # Formats the volume into either string displaying either litres or
  # millilitres.
  #
  # @return String
  def formatted_volume
    if volume.to_i >= 1000
      "#{volume / 100}lt"
    else
      "#{volume}ml"
    end
  end
end
