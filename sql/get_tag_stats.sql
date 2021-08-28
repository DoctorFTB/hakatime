WITH stats AS (
    SELECT
        total_stats.day,
        total_stats.dayofweek,
        total_stats.hourofday,
        coalesce(total_stats.language, 'Other') AS
        LANGUAGE,
        total_stats.entity,
        CAST(sum(extract(minute FROM previous_diff) * 60 + extract(second FROM previous_diff)) AS int8) AS total_seconds
    FROM (
        SELECT
            (CAST(extract(dow FROM (time_sent::date + interval '0h')) AS int8))::text AS dayofweek,
            (CAST(extract(hour FROM time_sent) AS int8))::text AS hourofday,
            time_sent::date + interval '0h' AS day,
            heartbeats.language,
            heartbeats.entity,
            (time_sent - (lag(time_sent) OVER (ORDER BY time_sent))) AS previous_diff
        FROM
            heartbeats
            JOIN project_tags ON project_tags.project_owner = sender AND project_tags.project_name = project
            JOIN tags ON tags.id = project_tags.tag_id
        WHERE
          heartbeats.sender = $1
            AND tags.name = $2
            AND heartbeats.time_sent >= $3
            AND heartbeats.time_sent <= $4
        ORDER BY
            heartbeats.time_sent) total_stats
    WHERE
        extract(epoch FROM previous_diff) <= ($5 * 60)
    GROUP BY
        total_stats.day,
        total_stats.dayofweek,
        total_stats.hourofday,
        total_stats.language,
        total_stats.entity
    ORDER BY
        total_stats.day
)
SELECT
    *,
    coalesce(CAST(1.0 * total_seconds / nullif (sum(total_seconds) OVER (), 0) AS numeric(13, 12)), 0) AS pct,
    coalesce(CAST(1.0 * total_seconds / nullif (sum(total_seconds) OVER (PARTITION BY day), 0) AS numeric(13, 12)), 0) AS daily_pct
FROM
    stats;

