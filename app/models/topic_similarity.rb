# Finds the topics of a project that read like some text, looking at the whole discussion (title,
# opening post and replies), not just titles. Each match carries a 0-100 percentage.
#
# The percentage is the better of two signals:
#   * title: fuzzy trigram match of the typed title against the topic title (typo and plural tolerant);
#   * discussion: cosine similarity of TF-IDF word vectors, so rare shared words count for more than
#     common ones, one shared word is a weak match, and what people said in the replies counts too.
# It is computed on every call (nothing is cached), so a new reply changes the result immediately.
class TopicSimilarity
  Match = Data.define(:topic, :percent)

  MIN_PERCENT = 20
  CORPUS_LIMIT = 500        # most recently active topics compared
  MESSAGES_PER_TOPIC = 50   # latest replies read per topic
  TITLE_WEIGHT = 3
  SUFFIXES = %w[ing ed es s e].freeze
  STOPWORDS = %w[the and for not with that this from are was were has have you your but all can will
                 que para com por uma uns dos das nao mais como mas
                 una los las del con por pero sin
                 les des pour dans est pas une sur avec
                 per che non gli del dei della con una].to_set.freeze

  # The related topics of an existing topic: its own whole discussion against the others.
  def self.for_topic(topic)
    replies = topic.messages.where(deleted_at: nil).order(:created_at).last(MESSAGES_PER_TOPIC).map(&:body)
    new(project: topic.project, title: topic.title, body: [ topic.body, *replies ].join(" "), exclude: topic.id)
  end

  def initialize(project:, title: "", body: "", exclude: nil)
    @project = project
    @title = title.to_s.strip
    @body = body.to_s
    @exclude = exclude
  end

  def matches(limit: 3)
    return [] if (@title + @body).strip.length < 3

    candidates = @candidates = load_candidates
    return [] if candidates.empty?

    docs = candidates.to_h { |topic| [ topic.id, document_vector(topic) ] }
    idf = idf_for(docs.values)
    query = weigh(query_terms, idf)

    candidates.filter_map do |topic|
      cosine = cosine(query, weigh(docs.fetch(topic.id), idf))
      percent = [ topic.title_score.to_f * 100, cosine * 100 ].max.round
      Match.new(topic: topic, percent: [ percent, 100 ].min) if percent >= MIN_PERCENT
    end.sort_by { |match| [ -match.percent, match.topic.id ] }.first(limit)
  end

  private

  def load_candidates
    scope = @project.topics.with_title_score(@title).order(last_activity_at: :desc, id: :desc).limit(CORPUS_LIMIT)
    scope = scope.where.not(id: @exclude) if @exclude
    scope.to_a
  end

  # term => raw count, for one topic: the title counts extra, then the post and the replies.
  def document_vector(topic)
    replies = replies_by_topic[topic.id].to_a.last(MESSAGES_PER_TOPIC)
    count(tokens(topic.title) * TITLE_WEIGHT + tokens(topic.body) + replies.flat_map { |body| tokens(body) })
  end

  def replies_by_topic
    @replies_by_topic ||= TopicMessage.where(topic_id: @candidates.map(&:id), deleted_at: nil)
                                      .order(:created_at).pluck(:topic_id, :body).group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  def query_terms
    count(tokens(@title) * TITLE_WEIGHT + tokens(@body))
  end

  def idf_for(vectors)
    total = vectors.size
    frequency = Hash.new(0)
    vectors.each { |vector| vector.each_key { |term| frequency[term] += 1 } }
    Hash.new { |_, _| Math.log(total + 1) + 1 }.tap do |idf|
      frequency.each { |term, df| idf[term] = Math.log((total + 1.0) / (df + 1)) + 1 }
    end
  end

  def weigh(vector, idf)
    vector.to_h { |term, tf| [ term, (1 + Math.log(tf)) * idf[term] ] }
  end

  def cosine(a, b)
    return 0.0 if a.empty? || b.empty?

    dot = a.sum { |term, weight| weight * b.fetch(term, 0) }
    dot / (Math.sqrt(a.values.sum { |w| w * w }) * Math.sqrt(b.values.sum { |w| w * w }))
  end

  def count(terms) = terms.tally

  def tokens(text)
    I18n.transliterate(text.to_s.downcase).scan(/[a-z0-9]+/).filter_map do |word|
      word = stem(word)
      word if word.length >= 3 && !STOPWORDS.include?(word)
    end
  end

  # A crude, language-agnostic stemmer: enough for plurals and common verb endings
  # (redirect/redirects/redirecting, expire/expires/expired).
  def stem(word)
    SUFFIXES.each { |suffix| return word.delete_suffix(suffix) if word.end_with?(suffix) && word.length - suffix.length >= 4 }
    word
  end
end
