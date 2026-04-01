class Api::V1::StreamController < Api::V1::PublicController
  def current
    session = StreamService.current_session

    if session.nil?
      render json: { session: nil, appearances: [], schedule: [], current_segment_id: nil, stats: nil }
      return
    end

    current_segment = StreamService.current_segment(session)
    current_segment_id = current_segment&.id
    schedule = StreamService.schedule_for(session)
    appearances = session.stream_appearances.includes(:user).where.not(role: :host)

    render json: {
      session: session.as_json(only: [ :id, :title, :youtube_url, :starts_at, :ends_at, :is_live ]),
      appearances: appearances.map do |a|
        { role: a.role, display_name: a.user.display_name, avatar: a.user.avatar }
      end,
      schedule: schedule.map do |day|
        {
          date: day[:date],
          segments: day[:segments].map do |seg|
            seg.as_json(only: [ :id, :label, :description, :kind, :starts_at, :ends_at ])
               .merge("is_current" => seg.id == current_segment_id)
          end
        }
      end,
      current_segment_id: current_segment_id,
      stats: StreamService.stats_for(session)
    }
  end
end
