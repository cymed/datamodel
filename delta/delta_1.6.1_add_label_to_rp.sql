CREATE OR REPLACE FUNCTION qgep_od.update_wastewater_structure_label(_obj_id text, _all boolean default false)
  RETURNS VOID AS
  $BODY$
  DECLARE
  myrec record;
  BEGIN
  
 --Update reach_point label
  UPDATE qgep_od.reach_point rp
  SET _label = rp_label.new_label
  FROM (
  with inp as( SELECT
    ne.fk_wastewater_structure
    , rp.obj_id
    , row_number() OVER(PARTITION BY NE.fk_wastewater_structure 
					ORDER BY ST_Azimuth(rp.situation_geometry,ST_PointN(re.progression_geometry,-2))/pi()*180 ASC) 
					as idx
    , count	(*) OVER(PARTITION BY NE.fk_wastewater_structure ) as max_idx				
      FROM qgep_od.reach_point rp
      LEFT JOIN qgep_od.wastewater_networkelement ne ON rp.fk_wastewater_networkelement = ne.obj_id
      INNER JOIN qgep_od.reach re ON rp.obj_id = re.fk_reach_point_to
      LEFT JOIN qgep_od.wastewater_networkelement ne_re ON ne_re.obj_id = re.obj_id
      LEFT JOIN qgep_od.channel ch ON ne_re.fk_wastewater_structure = ch.obj_id
	  LEFT JOIN qgep_od.wastewater_structure ws ON ne_re.fk_wastewater_structure = ws.obj_id
	  LEFT JOIN qgep_vl.channel_function_hierarchic vl_ch_fh ON vl_ch_fh.code = ch.function_hierarchic
	  LEFT JOIN qgep_vl.wastewater_structure_status vl_ws_st ON vl_ws_st.code = ws.status
	  WHERE left(vl_ch_fh.value_en,4)='pwwf' AND vl_ws_st.value_en ILIKE 'operational%'),
  outp as( SELECT
    ne.fk_wastewater_structure
    , rp.obj_id
    , row_number() OVER(PARTITION BY NE.fk_wastewater_structure 
					ORDER BY ST_Azimuth(rp.situation_geometry,ST_PointN(re.progression_geometry,-2))/pi()*180 ASC) 
					as idx
    , count	(*) OVER(PARTITION BY NE.fk_wastewater_structure ) as max_idx				
      FROM qgep_od.reach_point rp
      LEFT JOIN qgep_od.wastewater_networkelement ne ON rp.fk_wastewater_networkelement = ne.obj_id
      INNER JOIN qgep_od.reach re ON rp.obj_id = re.fk_reach_point_from
      LEFT JOIN qgep_od.wastewater_networkelement ne_re ON ne_re.obj_id = re.obj_id
      LEFT JOIN qgep_od.channel ch ON ne_re.fk_wastewater_structure = ch.obj_id
	  LEFT JOIN qgep_od.wastewater_structure ws ON ne_re.fk_wastewater_structure = ws.obj_id
	  LEFT JOIN qgep_vl.channel_function_hierarchic vl_ch_fh ON vl_ch_fh.code = ch.function_hierarchic
	  LEFT JOIN qgep_vl.wastewater_structure_status vl_ws_st ON vl_ws_st.code = ws.status
	  WHERE left(vl_ch_fh.value_en,4)='pwwf' AND vl_ws_st.value_en ILIKE 'operational%')
  SELECT 'I'||CASE WHEN max_idx=1 THEN '' ELSE idx::text END as new_label
  , obj_id
  FROM inp
    WHERE (_all AND inp.fk_wastewater_structure IS NOT NULL) OR inp.fk_wastewater_structure= _obj_id
  UNION
  SELECT 'O'||CASE WHEN max_idx=1 THEN '' ELSE idx::text END as new_label
  , obj_id
  FROM outp
  WHERE (_all AND outp.fk_wastewater_structure IS NOT NULL) OR outp.fk_wastewater_structure= _obj_id) rp_label
  WHERE rp_label.obj_id=rp.obj_id;
  
  --Update wastewater structure label
  -- 2023_05_12: use reach point labels
  UPDATE qgep_od.wastewater_structure ws
SET _label = label,
    _cover_label = cover_label,
    _bottom_label = bottom_label,
    _input_label = input_label,
    _output_label = output_label
    FROM(
SELECT   ws_obj_id,
          COALESCE(ws_identifier, '') as label,
          CASE WHEN count(co_level)<2 THEN array_to_string(array_agg(E'\nC' || '=' || co_level ORDER BY idx DESC), '', '') ELSE
		  array_to_string(array_agg(E'\nC' || idx || '=' || co_level ORDER BY idx ASC), '', '') END as cover_label,
          array_to_string(array_agg(E'\nB' || '=' || bottom_level), '', '') as bottom_label,
		  array_to_string(array_agg(E'\n'||rpi_label|| '=' || rpi_level ORDER BY rpi_label ASC), '', '')  as input_label,
		  array_to_string(array_agg(rpo_label|| '=' || rpo_level ORDER BY rpo_label ASC), '', '')  as output_label
		  FROM (
		  SELECT ws.obj_id AS ws_obj_id
		  , ws.identifier AS ws_identifier
		  , parts.co_level AS co_level
		  , parts.rpi_level AS rpi_level
		  , parts.rpo_level AS rpo_level
		  , parts.rpi_label AS rpi_label
		  , parts.rpo_label AS rpo_label
		  , parts.obj_id, idx
		  , parts.bottom_level AS bottom_level
    FROM qgep_od.wastewater_structure WS

    LEFT JOIN (
	  --cover	
      SELECT 
		coalesce(round(CO.level, 2)::text, '?') AS co_level
		, SP.fk_wastewater_structure ws
		, SP.obj_id
		, row_number() OVER(PARTITION BY SP.fk_wastewater_structure) AS idx
		, NULL::text AS bottom_level
		, NULL::text AS rpi_level
		, NULL::text  AS rpo_level
		, NULL::text as rpi_label
		, NULL::text  AS rpo_label
      FROM qgep_od.structure_part SP
      RIGHT JOIN qgep_od.cover CO ON CO.obj_id = SP.obj_id
      WHERE _all OR SP.fk_wastewater_structure = _obj_id
      -- Bottom
      UNION
      SELECT 
		NULL AS co_level
		, ws1.obj_id ws
		, NULL as obj_id
		, NULL as idx
		, round(wn.bottom_level, 2)::text AS wn_bottom_level
		, NULL::text AS rpi_level
		, NULL::text  AS rpo_level
		, NULL::text as rpi_label
		, NULL::text  AS rpo_label
      FROM qgep_od.wastewater_structure ws1
      LEFT JOIN qgep_od.wastewater_node wn ON wn.obj_id = ws1.fk_main_wastewater_node
      WHERE _all OR ws1.obj_id = _obj_id
	  UNION
	  --input	
      SELECT 
		NULL AS co_level
		, NE.fk_wastewater_structure ws
		, RP.obj_id
		,NULL as idx
		, NULL::text AS bottom_level
		, coalesce(round(RP.level, 2)::text, '?') AS rpi_level
		, NULL::text AS rpo_level
		, rp._label as rpi_label
		,  NULL::text AS rpo_label
      FROM qgep_od.reach_point RP
      LEFT JOIN qgep_od.wastewater_networkelement NE ON RP.fk_wastewater_networkelement = NE.obj_id
      WHERE (_all OR NE.fk_wastewater_structure = _obj_id) and left(RP._label,1)='I'
      -- output
      UNION
      SELECT  NULL AS co_level
		, NE.fk_wastewater_structure ws
		, RP.obj_id
		, NULL as idx
		, NULL::text AS bottom_level
		, NULL::text AS rpi_level
		, coalesce(round(RP.level, 2)::text, '?') AS rpo_level
		, NULL::text as rpi_label
		, rp._label AS rpo_label
      FROM qgep_od.reach_point RP
      LEFT JOIN qgep_od.wastewater_networkelement NE ON RP.fk_wastewater_networkelement = NE.obj_id
      WHERE (_all OR NE.fk_wastewater_structure = _obj_id) and left(RP._label,1)='O'
	) AS parts ON parts.ws = ws.obj_id
    WHERE TRUE OR ws.obj_id =_obj_id
		  ) parts
		  GROUP BY ws_obj_id, COALESCE(ws_identifier, '')
) labeled_ws
WHERE ws.obj_id = labeled_ws.ws_obj_id;

END

$BODY$
LANGUAGE plpgsql
VOLATILE;

SELECT qgep_od.update_wastewater_structure_label(NULL,true);
