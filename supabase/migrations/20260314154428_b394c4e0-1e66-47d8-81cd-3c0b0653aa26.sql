
DROP VIEW IF EXISTS public.v_project_current_stage;

ALTER TABLE public.project_stages ALTER COLUMN final_grade TYPE numeric USING final_grade::numeric;

CREATE OR REPLACE VIEW public.v_project_current_stage AS
SELECT p.id AS project_id,
    p.title AS project_title,
    p.global_status,
    p.asesor_id,
    p.created_at AS project_created_at,
    pr.id AS program_id,
    pr.name AS program_name,
    m.id AS modality_id,
    m.name AS modality_name,
    ps.id AS stage_id,
    ps.stage_name,
    ps.system_state,
    ps.official_state,
    ps.final_grade,
    ps.observations,
    ps.created_at AS stage_created_at,
    ps.updated_at AS stage_updated_at
   FROM projects p
     JOIN programs pr ON pr.id = p.program_id
     JOIN modalities m ON m.id = p.modality_id
     LEFT JOIN project_stages ps ON ps.project_id = p.id AND ps.created_at = (SELECT max(ps2.created_at) FROM project_stages ps2 WHERE ps2.project_id = p.id);
