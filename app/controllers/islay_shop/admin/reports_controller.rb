class IslayShop::Admin::ReportsController < IslayShop::Admin::ApplicationController
  before_filter :parse_dates, :only => [:index, :orders, :product, :sku]

  def index
    @top_ten  = OrderOverviewReport.top_ten(@report_range)
    @series   = OrderOverviewReport.series(@report_range)
    @totals   = OrderOverviewReport.aggregates(@report_range)
  end

  def orders
    @series   = OrderOverviewReport.series(@report_range)
    @totals   = OrderReport.aggregates(@report_range)
    @orders   = OrderReport.orders(@report_range)
  end

  def products
    @total_volume = ProductReport.total_volume
    @products     = ProductReport.product_summary
    @skus         = ProductReport.sku_summary

    @categories, @all_categories   = ProductReport.category_summary
  end

  def product
    @product  = Product.find(params[:id])
    @series   = ProductReport.product_series(@product.id, @report_range)
    @totals   = ProductReport.product_aggregates(@product.id, @report_range)
    @skus     = ProductReport.product_skus_summary(@product.id, @report_range)
    @orders   = ProductReport.orders(@product.id, @report_range)
  end

  def sku
    @product  = Product.find(params[:product_id])
    @sku      = Sku.find(params[:id])
    @series   = SkuReport.series(@sku.id, @report_range)
    @totals   = SkuReport.aggregates(@sku.id, @report_range)
    @orders   = SkuReport.orders(@sku.id, @report_range)
  end
end
