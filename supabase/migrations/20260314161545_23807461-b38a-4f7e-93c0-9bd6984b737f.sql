
DROP VIEW IF EXISTS public.v_catalog_projects;

CREATE OR REPLACE VIEW public.v_catalog_projects
WITH (security_invoker = on)
AS
SELECT p.id AS project_id,
    p.title,
    prog.name AS program_name,
    m.name AS modality_name,
    p.global_status,
    p.created_at,
    COALESCE(ps.stage_name::text, 'SIN_ASIGNAR'::text) AS current_stage,
    COALESCE(ps.official_state::text, 'SIN_ASIGNAR'::text) AS current_official_state,
    ( SELECT count(*)::integer AS count
           FROM project_members pm
          WHERE pm.project_id = p.id AND pm.role = 'AUTHOR'::member_role) AS author_count
   FROM projects p
     LEFT JOIN programs prog ON prog.id = p.program_id
     LEFT JOIN modalities m ON m.id = p.modality_id
     LEFT JOIN LATERAL ( SELECT ps2.stage_name,
            ps2.official_state
           FROM project_stages ps2
          WHERE ps2.project_id = p.id
          ORDER BY ps2.created_at DESC
         LIMIT 1) ps ON true;
