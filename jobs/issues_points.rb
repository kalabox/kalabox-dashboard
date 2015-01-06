require 'json'
require 'time'
require 'dashing'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '15m', :first_in => '1s' do |job|
  backend = GithubBackend.new()
  opened_series = [[],[]]
  closed_series = [[],[]]
  issues_by_points = backend.issue_count_by_points(
    :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']),
    :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
    :since=>ENV['SINCE']
  ).group_by_month(ENV['SINCE'].to_datetime)
  issues_by_points.each_with_index do |(period,issues),i|
    timestamp = Time.strptime(period, '%Y-%m').to_i

    total_points = 0;
    issues.each do |issue|
      total_points = total_points + issue.value
      #puts issue.key + issue.value.to_s
    end

    closed_count = total_points
    #puts "hello:" + closed_count.to_s
    closed_series[0] << {
      x: timestamp,
      y: closed_count
    }
    # Add empty second series stack, and extrapolate last month for better trend visualization
    closed_series[1] << {
      x: timestamp,
      y: (i == issues_by_points.count-1) ? GithubDashing::Helper.extrapolate_to_month(closed_count) : 0
    }
  end

  closed = closed_series[0][-1][:y] rescue 0
  closed_prev = closed_series[0][-2][:y] rescue 0
  trend_closed = GithubDashing::Helper.trend_percentage_by_month(closed_prev, closed)
  trend_class_closed = GithubDashing::Helper.trend_class(trend_closed)

  send_event('issues_points', {
    series: closed_series,
    displayedValue: closed,
    moreinfo: "",
    difference: trend_closed,
    trend_class: trend_class_closed,
    arrow: 'icon-arrow-' + trend_class_closed
  })
end
