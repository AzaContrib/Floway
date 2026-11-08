-- Per-upstream model filter mode and enabled public model list.
-- model_filter_mode is either 'blacklist' (default, all models enabled except
-- those in disabled_public_model_ids) or 'whitelist' (all models disabled
-- except those in enabled_public_model_ids).
ALTER TABLE upstreams ADD COLUMN model_filter_mode TEXT NOT NULL DEFAULT 'blacklist';
ALTER TABLE upstreams ADD COLUMN enabled_public_model_ids TEXT NOT NULL DEFAULT '[]';
