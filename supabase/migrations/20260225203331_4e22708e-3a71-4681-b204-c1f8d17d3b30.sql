
-- Primero eliminar la vista dependiente
DROP VIEW IF EXISTS public.v_catalog_projects;
-- Luego eliminar la vista base
DROP VIEW IF EXISTS public.v_project_current_stage;

-- Recrear v_project_current_stage con LEFT JOIN
CREATE VIEW public.v_project_current_stage AS
SELECT
  p.id        AS project_id,
  p.title     AS project_title,
  p.global_status,
  p.asesor_id,
  p.created_at AS project_created_at,
  pr.id       AS program_id,
  pr.name     AS program_name,
  m.id        AS modality_id,
  m.name      AS modality_name,
  ps.id       AS stage_id,
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
LEFT JOIN project_stages ps
  ON ps.project_id = p.id
  AND ps.created_at = (
    SELECT max(ps2.created_at)
    FROM project_stages ps2
    WHERE ps2.project_id = p.id
  );

-- Recrear v_catalog_projects con COALESCE para proyectos sin etapa
CREATE VIEW public.v_catalog_projects AS
SELECT
  v.project_id,
  v.project_title   AS title,
  v.program_name,
  v.modality_name,
  v.global_status,
  v.project_created_at AS created_at,
  COALESCE(v.stage_name::text, 'SIN_ASIGNAR')   AS current_stage,
  COALESCE(v.official_state::text, 'SIN_ASIGNAR') AS current_official_state,
  (SELECT count(*) FROM project_members pm
   WHERE pm.project_id = v.project_id AND pm.role = 'AUTHOR')::integer AS author_count
FROM v_project_current_stage v;
