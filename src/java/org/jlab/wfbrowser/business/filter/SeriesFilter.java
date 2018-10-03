/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package org.jlab.wfbrowser.business.filter;

import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author adamc
 */
public class SeriesFilter {

    private String name;
    private String system;
    private List<Integer> idList;

    public SeriesFilter(String name, String system, List<Integer> idList) {
        this.name = name;
        this.system = system;
        this.idList = idList;
    }

    public String getWhereClause() {
        String filter = "";
        List<String> filters = new ArrayList<>();

        if (idList != null && !idList.isEmpty()) {
            String idFilter = "series_id IN (?";
            for (int i = 0; i < idList.size(); i++) {
                idFilter += ",?";
            }
            idFilter += ")";
            filters.add(idFilter);
        }

        if (name != null) {
            filters.add("name = ?");
        }
        if (system != null) {
            filters.add("system_name = ?");
        }

        if (!filters.isEmpty()) {
            filter = "WHERE " + filters.get(0);

            if (filters.size() > 1) {
                for (int i = 1; i < filters.size(); i++) {
                    filter = filter + " AND " + filters.get(i);
                }
            }
        }
        return filter;
    }

    /**
     * Assign the filter parameters to a Prepared Statement.  This statement should be of the same format as generated by
     * this class
     * @param stmt
     * @throws SQLException 
     */
    public void assignParameterValues(PreparedStatement stmt) throws SQLException {
        int i = 1;

        if (idList != null && !idList.isEmpty()) {
            for (Integer id : idList) {
                stmt.setInt(i++, id);
            }
        }
        if (name != null) {
            stmt.setString(i++, name);
        }
        if (system != null) {
            stmt.setString(i++, system);
        }
    }
}