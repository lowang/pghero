module PgHero
  module Methods
    module Sequences
      def sequences
        sequences = select_all <<-SQL
          SELECT
            n.nspname AS schema,
            c.relname AS table,
            attname AS column,
            format_type(a.atttypid, a.atttypmod) AS column_type,
            CASE WHEN format_type(a.atttypid, a.atttypmod) = 'integer' THEN 2147483647::bigint ELSE (pg_sequence_parameters(s.oid)).maximum_value::bigint END AS max_value,
            s.relname AS sequence
          FROM
            pg_catalog.pg_attribute a
          INNER JOIN
            pg_catalog.pg_class c ON c.oid = a.attrelid
          INNER JOIN
            pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          LEFT JOIN
            pg_catalog.pg_attrdef d ON (a.attrelid, a.attnum) = (d.adrelid,  d.adnum)
          INNER JOIN
            pg_catalog.pg_class s ON s.relkind = 'S'
            AND s.relname = regexp_replace(d.adsrc, '^nextval\\(''(.*)''\\:\\:regclass\\)$', '\\1')
          WHERE
            NOT a.attisdropped
            AND a.attnum > 0
            AND d.adsrc LIKE 'nextval%'
          ORDER BY
            s.relname ASC
        SQL

        select_all(sequences.map { |s| "SELECT last_value FROM #{quote_ident(s[:sequence])}" }.join(" UNION ALL ")).each_with_index do |row, i|
          sequences[i][:last_value] = row[:last_value]
        end

        sequences
      end

      def sequence_danger(threshold: 0.9)
        sequences.select { |s| s[:last_value] / s[:max_value].to_f > threshold }.sort_by { |s| s[:max_value] - s[:last_value] }
      end
    end
  end
end
