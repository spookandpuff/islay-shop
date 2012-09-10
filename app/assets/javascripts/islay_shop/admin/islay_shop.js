//= require ../../vendor/raphael-min
//= require ../../vendor/g.raphael-min
//= require ../../vendor/g.pie-min
//= require ../../vendor/g.line-min

var IslayShop = {};

/* -------------------------------------------------------------------------- */
/* UTILS
/* -------------------------------------------------------------------------- */
IslayShop.u = {
  formatMoney: function(v) {
    return '$' + v.toFixed(2);
  }
};

/* -------------------------------------------------------------------------- */
/* SEGMENTED CONTROL
/* Simplistic, report-specific segmented control.
/* -------------------------------------------------------------------------- */
IslayShop.SegmentedControl = Backbone.View.extend({
  tagName: 'ul',
  className: 'segmented',
  events: {'click li': 'click'},

  initialize: function() {
    _.bindAll(this, 'click');
    this.lis = [];
  },

  click: function(e) {
    var $target = $(e.target),
        index = parseInt($target.attr('data-index'));

    if (index !== this.current) {
      var current = this.lis[this.current];
      current.removeClass('current');
      $target.addClass('current');
      this.current = index;
      this.trigger('selected', index);
    }
  },

  render: function() {
    _.each(this.options.labels, function(label, i) {
      var li = $H('li[data-index=' + i + ']', label);
      this.$el.append(li);
      this.lis.push(li);

      if (i === 0) {
        this.current = i;
        li.addClass('current');
      }
    }, this);

    return this;
  }
});

/* -------------------------------------------------------------------------- */
/* LINE GRAPH
/* Wraps gRaphael line graphs. Makes it easier to render.
/* -------------------------------------------------------------------------- */
IslayShop.LineGraph = Backbone.View.extend({
  className: 'graph',

  initialize: function() {
    this.x = this.options.values.x;
    this.y = this.options.values.y;
    this.xLabels = this.options.values.xLabels;
  },

  render: function() {
    this.paper = Raphael(this.el);

    var opts = {symbol: 'circle', axis: '0 0 1 1', axisxstep: this.x.length - 1, axisystep: 5, gutter: 10, colors: [this.options.values.color]};
    this.line = this.paper.linechart(30, 0, 500, 250, this.x, this.y, opts);

    // These callbacks are defined inline, and we use the behaviour of closures
    // to keep our view in scope and call our own handlers. This is because of
    // gRaphael's limited callbacks.
    var view = this;
    this.line.hoverColumn(function() {view.hoverIn(this);}, function() {view.hoverOut(this);});

    if (this.xLabels) {this.renderXLabels(this.xLabels)};

    return this;
  },

  hide: function() {
    this.$el.hide();
    return this;
  },

  show: function() {
    this.$el.show();
    return this;
  },

  hoverIn: function(cover) {
    this.tags = []

    for (var i = 0, ii = cover.y.length; i < ii; i++) {
      var tag = $H('div.tag', IslayShop.u.formatMoney(cover.values[i]));
      this.tags.push(tag);
      this.$el.append(tag);
      tag.css({left: cover.x, top: cover.y[i] - (tag.outerHeight() / 2)});
    }
  },

  hoverOut: function() {
    this.tags && _.each(this.tags, function(tag) {tag.remove();});
  },

  renderXLabels: function(labels) {
    var els = this.line.axis[0].text.items;
    _.each(labels, function(label, i) {els[i].attr({text: label});});
  }
});

/* -------------------------------------------------------------------------- */
/* SERIES GRAPH
/* -------------------------------------------------------------------------- */
IslayShop.SeriesGraph = Backbone.View.extend({
  className: 'series-graph',

  initialize: function() {
    _.bindAll(this, 'toggle');

    this.current = 0;

    this.values = {
      value:      {x: [], y: [], xLabels: [], color: 'green'},
      volume:     {x: [], y: [], xLabels: [], color: 'blue'},
      sku_volume: {x: [], y: [], xLabels: [], color: 'red'}
    };

    _.each(this.options.table.find('tbody tr'), function(el, i) {
      var values = _.map($(el).find('td:not(:first-child)'), function(el) {
        return parseInt($(el).text());
      })

      this.update('value', i, values[0], i + 1);
      this.update('volume', i, values[1], i + 1);
      this.update('sku_volume', i, values[2], i + 1);
    }, this);

    this.graphs = _.map(this.values, function(v) {
      return new IslayShop.LineGraph({color: 'blue', values: v});
    });

    var ths    = this.options.table.find('thead th:gt(0)'),
        labels = _.map(ths, function(th) {return $(th).text();});

    this.controls = new IslayShop.SegmentedControl({labels: labels});
    this.controls.on('selected', this.toggle);

    this.render();
  },

  toggle: function(index) {
    this.graphs[this.current].hide();
    this.graphs[index].show();
    this.current = index;
  },

  update: function(key, x, y, label) {
    var v = this.values[key];
    v.x.push(x);
    v.y.push(y);
    if (label) {v.xLabels.push(label);}
  },

  render: function() {
    this.options.table.before(this.$el).remove();

    this.$el.append(this.controls.render().el);

    _.each(this.graphs, function(view, i) {
      this.$el.append(view.el);
      view.render();

      if (i > 0) {view.hide();}
    }, this);

    return this;
  }
});

/* -------------------------------------------------------------------------- */
/* SORTABLE TABLE
/* -------------------------------------------------------------------------- */
IslayShop.SortableTable = Backbone.View.extend({
  events: {'click thead th': 'click'},

  initialize: function() {
    _.bindAll(this, 'click');

    this.$el.addClass('sortable');

    this.body = this.$el.find('tbody');

    this.types = _.map(this.body.find('tr:first-child td'), function(td) {
      var raw = $(td).text();
      if (/^[\$]?\d+\.\d{2}$/.test(raw)) {
        return 'monentary';
      }
      else if (/^\d+$/.test(raw)) {
        return 'integer';
      }
      else {
        return 'string';
      }
    });

    this.columns = [];

    _.each(this.$el.find('tbody tr'), function(row) {
      var $row = $(row);
      _.each($row.find('td'), function(td, i) {
        column = this.columns[i] || (this.columns[i] = [])
        column.push([this._coerce(i, $(td).text()), $row]);
      }, this);
    }, this);

    this.ths = _.map(this.$el.find('thead th'), function(th, i) {
      var $th = $(th);
      $th.attr('data-index', i);
      if ($th.is('.sorted')) {this.current = i;}
      return $th;
    }, this);

  },

  _coerce: function(i, val) {
    switch(this.types[i]) {
      case 'monentary':
        return parseFloat(val.split('$')[1]);
      case 'integer':
        return parseInt(val);
      case 'string':
        return val;
    }
  },

  click: function(e) {
    var $target = $(e.target),
        index = parseInt($target.attr('data-index'));

    if (!$target.is('.sorted')) {
      this.ths[this.current].removeClass('sorted');
      $target.addClass('sorted');
      this.current = index;

      var column = this.columns[index];
      if (this.types[index] === 'string') {
        column.sort(this._alphaSort);
      }
      else {
        column.sort(this._numericSort);
      }
      this.body.find('tr').detach();
      _.each(column, function(row) {this.body.append(row[1])}, this);
    }
  },

  _alphaSort: function(x, y) {
    if (x[0] < y[0]) return -1;
    if (x[0] > y[0]) return 1;
    return 0;
  },

  _numericSort: function(x, y) {
    if (x[0] < y[0]) return 1;
    if (x[0] > y[0]) return -1;
    return 0;
  }
});

/* -------------------------------------------------------------------------- */
/* TABBED TABLE CELL
/* -------------------------------------------------------------------------- */
IslayShop.TabbedTables = Backbone.View.extend({
  initialize: function() {
    _.bindAll(this, 'toggle');

    this.tables = [];
    this.current = 0;
    var labels = [];

    _.each(this.$el.find('table'), function(table, i) {
      var $table = $(table);
      this.tables.push($table);
      labels.push($table.find('caption').text());
    }, this);

    this.controls = new IslayShop.SegmentedControl({labels: labels});
    this.controls.on('selected', this.toggle);

    this.render();
  },

  toggle: function(index) {
    this.tables[this.current].hide();
    this.tables[index].show();
    this.current = index;
  },

  render: function() {
    this.$el.find('h3').after(this.controls.render().el);
    _.each(this.tables, function(table, i) {
      if (this.options.sortable === true) {
        var view = new IslayShop.SortableTable({el: table});
      }
      if (i > 0) {
        table.hide();
      }
    }, this);

    return this;
  }
});

$SP.where('#islay-shop-admin-reports.index').run(function() {
  var graph = new IslayShop.SeriesGraph({table: $('.series-graph')});
  var topTen = new IslayShop.TabbedTables({el: $("#top-ten")});
});

$SP.where('#islay-shop-admin-reports.products').run(function() {
  var tabs = new IslayShop.TabbedTables({el: $("#product-listing"), sortable: true});
});