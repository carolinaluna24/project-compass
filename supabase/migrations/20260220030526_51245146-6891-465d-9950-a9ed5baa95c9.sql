
-- 1. Rename DIRECTOR → ASESOR in app_role enum
ALTER TYPE public.app_role RENAME VALUE 'DIRECTOR' TO 'ASESOR';

-- 2. Rename DIRECTOR → ASESOR in member_role enum
ALTER TYPE public.member_role RENAME VALUE 'DIRECTOR' TO 'ASESOR';

-- 3. Rename projects.director_id → projects.asesor_id
ALTER TABLE public.projects RENAME COLUMN director_id TO asesor_id;

-- 4. Update has_project_access function to use asesor_id
CREATE OR REPLACE FUNCTION public.has_project_access(p_project_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT public.is_coordinator(p_user_id)
    OR public.is_project_member(p_project_id, p_user_id)
    OR public.is_assigned_to_project(p_project_id, p_user_id)
    OR EXISTS (SELECT 1 FROM public.projects WHERE id = p_project_id AND asesor_id = p_user_id)
$$;

-- 5. Drop dependent views with CASCADE and recreate both
DROP VIEW IF EXISTS public.v_project_current_stage CASCADE;

CREATE VIEW public.v_project_current_stage AS
SELECT
  p.id AS project_id,
  p.title AS project_title,
  p.program_id,
  prog.name AS program_name,
  p.modality_id,
  m.name AS modality_name,
  p.global_status,
  p.asesor_id,
  p.created_at AS project_created_at,
  ps.id AS stage_id,
  ps.stage_name,
  ps.system_state,
  ps.official_state,
  ps.final_grade,
  ps.observations,
  ps.created_at AS stage_created_at,
  ps.updated_at AS stage_updated_at
FROM public.projects p
JOIN public.project_stages ps ON ps.project_id = p.id
LEFT JOIN public.programs prog ON prog.id = p.program_id
LEFT JOIN public.modalities m ON m.id = p.modality_id
WHERE ps.created_at = (
  SELECT MAX(ps2.created_at)
  FROM public.project_stages ps2
  WHERE ps2.project_id = p.id
);

-- 6. Recreate v_catalog_projects (depends on v_project_current_stage)
CREATE VIEW public.v_catalog_projects AS
SELECT
  project_id,
  project_title AS title,
  program_name,
  modality_name,
  global_status,
  project_created_at AS created_at,
  stage_name AS current_stage,
  official_state AS current_official_state,
  (SELECT COUNT(*)::integer FROM project_members pm WHERE pm.project_id = v.project_id AND pm.role = 'AUTHOR') AS author_count
FROM public.v_project_current_stage v;

-- 7. Update projects_select RLS policy to reference asesor_id
DROP POLICY IF EXISTS "projects_select" ON public.projects;
CREATE POLICY "projects_select" ON public.projects
FOR SELECT TO authenticated
USING (
  (created_by = auth.uid())
  OR is_coordinator(auth.uid())
  OR is_decano(auth.uid())
  OR is_project_member(id, auth.uid())
  OR is_assigned_to_project(id, auth.uid())
  OR (asesor_id = auth.uid())
);

-- 8. Update endorsements_insert RLS policy to use ASESOR
DROP POLICY IF EXISTS "endorsements_insert" ON public.endorsements;
CREATE POLICY "endorsements_insert" ON public.endorsements
FOR INSERT TO authenticated
WITH CHECK (is_coordinator(auth.uid()) OR has_role(auth.uid(), 'ASESOR'::app_role));
