CREATE OR REPLACE FUNCTION nearby_pages(embedding vector, owner_id int, similarity_top_k int)
    RETURNS TABLE(id bigint, distance float8, contents text) 
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.embedding <=> embedding AS distance,
        p.contents
    FROM 
        Pages p
    JOIN 
        Inodes i ON p.inode_id = i.id
    WHERE 
        i.owner_id = owner_id
        AND p.embedding IS NOT NULL
    ORDER BY 
        distance ASC
    LIMIT 
        similarity_top_k;
END;
$$;
