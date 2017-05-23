# frozen_string_literal: true

# NOTE: This is meant for displaying old content of the phpBB forum. It is DEPRECATED!

class Forum < ApplicationRecord
  self.table_name = "phpbb3_forums"
  self.primary_key = "forum_id"
  establish_connection ActiveRecord::Base.connection_config.merge(database: "cubing_phpbb")

  has_many :forum_topics

  # Don't bother with private forums.
  default_scope { where(forum_name: ["WCA Organisation", "WCA Regulations", "WCA Competitions", "WCA Records and Rankings", "WCA Website"]) }
end