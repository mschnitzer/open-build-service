xml.maintenanceincident(project: @project.name) do
  xml.entry(type: :release_request_accepted, when: @request.accept_at)

  @request.reviews.not_assigned.each do |review|
    if review.state == :accepted
      xml.entry(type: :review_accepted, who: review.reviewer, id: review.id, when: review.accepted_at)
    end

    xml.entry(type: :review_opened, who: review.reviewer, id: review.id, when: review.created_at)
  end

  xml.entry(type: :release_request_created, when: @request.created_at)
  xml.entry(type: :project_created, when: @project.created_at)

  @issues.each do |issue|
    xml.entry(type: :issue_created, name: issue.name, tracker: issue.issue_tracker.name, when: issue.created_at)
  end
end
