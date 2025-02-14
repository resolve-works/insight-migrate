
-- https://github.com/pgvector/pgvector?tab=readme-ov-file#hnsw
-- https://jkatz05.com/post/postgres/pgvector-scalar-binary-quantization/
CREATE INDEX ON private.pages USING hnsw ((embedding::halfvec(1536)) halfvec_ip_ops);
