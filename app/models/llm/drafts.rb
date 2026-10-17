# AI drafts built from a topic's discussion: a task, or a chain of ordered steps.
module Llm::Drafts
  MAX_CONTEXT = 12_000
  SYSTEM = "You are ShipUp's planning assistant. You turn a product/engineering discussion into concrete, " \
           "small work items. Be specific, use the discussion's own wording, never invent facts. " \
           "Estimates are in working days (0.5 to 5).".freeze

  TaskDraft = Data.define(:title, :description)
  ChainDraft = Data.define(:title, :steps) # steps: [{ title:, description:, days: }]

  module_function

  def task(topic, client: Llm.client)
    data = ask(client, <<~PROMPT)
      Draft ONE task from this discussion. Answer as JSON: {"title": "...", "description": "..."}.
      The title is imperative and under 80 characters. The description is plain text: a short summary, then a
      "What we agreed" list of checklist lines (one per agreed action, prefixed with "- ").

      #{conversation(topic)}
    PROMPT
    TaskDraft.new(title: data["title"].to_s.strip.presence || topic.title, description: data["description"].to_s.strip)
  end

  def chain(topic, client: Llm.client)
    data = ask(client, <<~PROMPT)
      Draft a CHAIN of 2 to 5 steps that must ship in order, from this discussion. Answer as JSON:
      {"title": "...", "steps": [{"title": "...", "description": "...", "days": 2}]}.
      Step titles are one or two words (like "Backend", "Dashboard", "QA"); descriptions are one short sentence.

      #{conversation(topic)}
    PROMPT
    steps = Array(data["steps"]).filter_map do |step|
      next if step["title"].blank?

      { title: step["title"].to_s.strip, description: step["description"].to_s.strip, days: step["days"].to_f.positive? ? step["days"].to_f : nil }
    end
    raise Llm::Error, "the model returned no steps" if steps.empty?

    ChainDraft.new(title: data["title"].to_s.strip.presence || topic.title, steps: steps)
  end

  # Topic text plus replies, oldest first, trimmed to fit the context budget.
  def conversation(topic)
    lines = [ "Topic (#{topic.kind}): #{topic.title}", topic.body.to_s ]
    topic.messages.includes(:author).order(:created_at, :id).each { |message| lines << "#{message.author.short_name}: #{message.body}" }
    lines.join("\n").truncate(MAX_CONTEXT)
  end

  def ask(client, prompt)
    parse_json(client.complete(prompt, system: SYSTEM, max_tokens: 900, json: true))
  end

  # Models sometimes wrap JSON in code fences or add a sentence around it.
  def parse_json(text)
    cleaned = text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
    JSON.parse(cleaned[/\{.*\}/m] || cleaned)
  rescue JSON::ParserError
    raise Llm::Error, "the model did not return valid JSON"
  end
end
