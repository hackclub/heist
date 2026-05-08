# frozen_string_literal: true

module AdminHelper
  def admin_tab_link(label, path)
    classes = [ "heist-admin__tab" ]
    classes << "heist-admin__tab--active" if request.path.start_with?(path) && path != "/"
    link_to label, path, class: classes.join(" ")
  end

  def percent(numerator, denominator)
    return 0 if denominator.to_i.zero?
    (numerator.to_f / denominator * 100).round(1)
  end

  # Builds an SVG polyline `points` string. `values` is a numeric series.
  # Coordinates are (0,0)=top-left; we invert so high values plot at the top.
  def sparkline_points(values, width: 80, height: 24, padding: 2)
    return "" if values.blank?

    max = values.map(&:to_f).max.to_f
    span = [ values.size - 1, 1 ].max
    inner_w = width - 2 * padding
    inner_h = height - 2 * padding

    values.each_with_index.map do |v, i|
      x = padding + (i.to_f * inner_w / span)
      y = max.zero? ? (height - padding) : (padding + inner_h * (1 - v.to_f / max))
      "#{x.round(2)},#{y.round(2)}"
    end.join(" ")
  end

  # Builds the polyline points for the cumulative pace chart.
  # `points` is the controller's @pace_points array.
  def pace_chart_points(points, width:, height:, hour_goal:, total_days:, padding:)
    return "" if points.blank?

    inner_w = width - 2 * padding
    inner_h = height - 2 * padding
    span_days = [ total_days, 1.0 ].max
    span_hours = [ hour_goal, 1 ].max

    points.map do |p|
      x = padding + (p[:day_index].to_f * inner_w / span_days)
      y = padding + inner_h * (1 - (p[:cumulative_hours].to_f / span_hours).clamp(0.0, 1.0))
      "#{x.round(2)},#{y.round(2)}"
    end.join(" ")
  end

  # Endpoint coords (x,y) for a pace line from (start_day, start_hours) to
  # (end_day, end_hours), in the same coordinate space as pace_chart_points.
  def pace_chart_xy(day, hours, width:, height:, hour_goal:, total_days:, padding:)
    inner_w = width - 2 * padding
    inner_h = height - 2 * padding
    span_days = [ total_days, 1.0 ].max
    span_hours = [ hour_goal, 1 ].max
    x = padding + (day.to_f * inner_w / span_days)
    y = padding + inner_h * (1 - (hours.to_f / span_hours).clamp(0.0, 1.0))
    [ x.round(2), y.round(2) ]
  end

  def short_time_ago(time)
    return "—" if time.blank?
    time_ago_in_words(time).gsub(/about |less than /, "")
  end
end
