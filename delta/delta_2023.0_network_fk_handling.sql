-- Table: qgep_network.node
ALTER TABLE qgep_network.node 
DROP CONSTRAINT node_ne_id_fkey,
DROP CONSTRAINT node_rp_id_fkey;
--recreate constraints
ALTER TABLE qgep_network.node 
    ADD CONSTRAINT node_ne_id_fkey FOREIGN KEY (ne_id)
        REFERENCES qgep_od.wastewater_networkelement (obj_id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    ADD CONSTRAINT node_rp_id_fkey FOREIGN KEY (rp_id)
        REFERENCES qgep_od.reach_point (obj_id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

-- Table: qgep_network.segment

ALTER TABLE qgep_network.segment 
DROP CONSTRAINT segment_from_node_fkey,
DROP CONSTRAINT segment_ne_id_fkey,
DROP CONSTRAINT segment_to_node_fkey;
--recreate constraints
ALTER TABLE qgep_network.segment 
    ADD CONSTRAINT segment_from_node_fkey FOREIGN KEY (from_node)
        REFERENCES qgep_network.node (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    ADD CONSTRAINT segment_ne_id_fkey FOREIGN KEY (ne_id)
        REFERENCES qgep_od.wastewater_networkelement (obj_id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    ADD CONSTRAINT segment_to_node_fkey FOREIGN KEY (to_node)
        REFERENCES qgep_network.node (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;
