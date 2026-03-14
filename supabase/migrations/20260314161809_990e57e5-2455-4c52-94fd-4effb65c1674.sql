
-- 1. Revertir v_catalog_projects a security_invoker = off
DROP VIEW IF EXISTS public.v_catalog_projects;
CREATE OR REPLACE VIEW public.v_catalog_projects AS
SELECT p.id AS project_id,
    p.title,
    prog.name AS program_name,
    m.name AS modality_name,
    p.global_status,
    p.created_at,
    COALESCE(ps.stage_name::text, 'SIN_ASIGNAR'::text) AS current_stage,
    COALESCE(ps.official_state::text, 'SIN_ASIGNAR'::text) AS current_official_state,
    ( SELECT count(*)::integer FROM project_members pm WHERE pm.project_id = p.id AND pm.role = 'AUTHOR'::member_role) AS author_count
   FROM projects p
     LEFT JOIN programs prog ON prog.id = p.program_id
     LEFT JOIN modalities m ON m.id = p.modality_id
     LEFT JOIN LATERAL ( SELECT ps2.stage_name, ps2.official_state
           FROM project_stages ps2
          WHERE ps2.project_id = p.id
          ORDER BY ps2.created_at DESC
         LIMIT 1) ps ON true;

-- 2. Activar security_invoker en v_project_current_stage
DROP VIEW IF EXISTS public.v_project_current_stage;
CREATE OR REPLACE VIEW public.v_project_current_stage
WITH (security_invoker = on)
AS
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

-- 3. Activar security_invoker en v_deadlines_risk
DROP VIEW IF EXISTS public.v_deadlines_risk;
CREATE OR REPLACE VIEW public.v_deadlines_risk
WITH (security_invoker = on)
AS
SELECT d.id AS deadline_id,
    d.due_date,
    d.description AS deadline_description,
    d.created_at AS deadline_created_at,
    ps.id AS stage_id,
    ps.stage_name,
    ps.system_state,
    ps.official_state,
    ps.project_id,
    p.title AS project_title,
    p.global_status,
    prog.name AS program_name,
    EXTRACT(day FROM d.due_date - now())::integer AS days_remaining,
    CASE
        WHEN d.due_date < now() THEN 'VENCIDO'::text
        WHEN d.due_date <= (now() + '3 days'::interval) THEN 'POR_VENCER'::text
        ELSE 'ACTIVO'::text
    END AS risk_status
   FROM deadlines d
     JOIN project_stages ps ON ps.id = d.project_stage_id
     JOIN projects p ON p.id = ps.project_id
     LEFT JOIN programs prog ON prog.id = p.program_id
  ORDER BY d.due_date;
