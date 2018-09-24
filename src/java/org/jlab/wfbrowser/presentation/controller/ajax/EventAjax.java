/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package org.jlab.wfbrowser.presentation.controller.ajax;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;
import java.sql.SQLException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.json.Json;
import javax.json.JsonArrayBuilder;
import javax.json.JsonObjectBuilder;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.jlab.wfbrowser.business.filter.WaveformFilter;
import org.jlab.wfbrowser.business.service.WaveformService;
import org.jlab.wfbrowser.business.util.TimeUtil;

/**
 *
 * @author adamc
 */
@WebServlet(name = "event", urlPatterns = {"/ajax/event"})
public class EventAjax extends HttpServlet {

    private final static Logger LOGGER = Logger.getLogger(EventAjax.class.getName());

    // <editor-fold defaultstate="collapsed" desc="HttpServlet methods. Click on the + sign on the left to edit the code.">
    /**
     * Handles the HTTP <code>GET</code> method. Used to query for "EventAjax"
     * data as REST API end point.
     *
     * @param request servlet request
     * @param response servlet response
     * @throws ServletException if a servlet-specific error occurs
     * @throws IOException if an I/O error occurs
     */
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("application/json");
        String[] eArray = request.getParameterValues("id");
        List<Long> eventIdList = null;
        if (eArray != null) {
            eventIdList = new ArrayList<>();
            for (String eventId : eArray) {
                if (eventId != null && (!eventId.isEmpty())) {
                    eventIdList.add(Long.valueOf(eventId));
                }
            }
        }

        Instant begin = TimeUtil.getInstantFromDateTimeString(request.getParameter("begin"));
        Instant end = TimeUtil.getInstantFromDateTimeString(request.getParameter("end"));
        String system = request.getParameter("system");
        system = system == null ? "rf" : system;
        String location = request.getParameter("location");
        String arch = request.getParameter("archive");
        Boolean archive = (arch == null) ? null : arch.equals("true");
        String del = request.getParameter("toDelete");
        Boolean delete = (del == null) ? null : del.equals("true");
        Boolean includeData = Boolean.getBoolean(request.getParameter("includeData"));  // false if not supplied or not "true"
        // TODO: test out these changes!!

        if (eventIdList != null && eventIdList.isEmpty()) {
            try (PrintWriter pw = response.getWriter()) {
                response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
                pw.write("{\"error\": \"No event IDs specified\"}");
            }
            return;
        }

        WaveformService wfs = new WaveformService();
        // Enforce an rf system filter since this is likely to be an interface for only RF systems for some time
        WaveformFilter filter = new WaveformFilter(eventIdList, begin, end, system, location, archive, delete);

        JsonObjectBuilder job = null;
        try {
            List<org.jlab.wfbrowser.model.Event> eventList;
            if (includeData) {
                eventList = wfs.getEventList(filter);
            } else {
                eventList = wfs.getEventListWithoutData(filter);
            }
            job = Json.createObjectBuilder();
            JsonArrayBuilder jab = Json.createArrayBuilder();
            for (org.jlab.wfbrowser.model.Event e : eventList) {
                jab.add(e.toJsonObject());
            }
            job.add("events", jab.build());
        } catch (SQLException ex) {
            LOGGER.log(Level.SEVERE, "Error querying database");
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            try (PrintWriter pw = response.getWriter()) {
                pw.print("{\"error\": \"error querying database - " + ex.getMessage() + "\"}");
            }
        } catch (FileNotFoundException ex) {
            LOGGER.log(Level.SEVERE, "Error querying data - {0}", ex.getMessage());
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            try (PrintWriter pw = response.getWriter()) {
                pw.print("{\"error\": \"error querying data - " + ex.getMessage() + "\"}");
            }

        }

        try (PrintWriter pw = response.getWriter()) {
            if (job != null) {
                pw.print(job.build().toString());
            } else {
                pw.print("{\"error\":\"null response\"}");
            }
        }

    }

    /**
     * Handle logic for events to be added to waveform database. Part of REST
     * API.
     *
     * @param request
     * @param response
     * @throws ServletException
     * @throws IOException
     */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String datetime = request.getParameter("datetime");
        String location = request.getParameter("location");
        String system = request.getParameter("system");
        String archive = request.getParameter("archive");
        String delete = request.getParameter("delete");
        response.setContentType("application/json");

        if (datetime == null || location == null || system == null) {
            try (PrintWriter pw = response.getWriter()) {
                response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
                pw.write("{\"error\": \"Missing required argument.  Requires datetime, location, system\"}");
            }
            return;
        }

        Instant t = TimeUtil.getInstantFromDateTimeString(datetime);
        WaveformService wfs = new WaveformService();
        try {

            Boolean arch = archive != null;
            Boolean del = delete != null;
            org.jlab.wfbrowser.model.Event event = new org.jlab.wfbrowser.model.Event(t, location, system, arch, del, null);
            long id = wfs.addEvent(event, false);
            try (PrintWriter pw = response.getWriter()) {
                pw.write("{\"id\": \"" + id + "\", \"message\": \"Waveform event successfully added to database\"}");
            }
        } catch (SQLException e) {
            try (PrintWriter pw = response.getWriter()) {
                response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                pw.write("{\"error\": \"Problem updating database - " + e.toString() + "\"}");
            }
        }

    }

    @Override
    protected void doPut(HttpServletRequest request, HttpServletResponse response) throws IOException {
        response.setContentType("application/json");
        String id = request.getParameter("id");
        String arch = request.getParameter("archive");
        String del = request.getParameter("delete");
        Long eventId;

        if (id == null || id.isEmpty()) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            try (PrintWriter pw = response.getWriter()) {
                pw.write("{\"error\": \"id must be specified and a valid long integer\"}");
            }
            return;
        }

        try {
            eventId = Long.parseLong(id);
        } catch (NumberFormatException ex) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            try (PrintWriter pw = response.getWriter()) {
                pw.write("{\"error\": \"id must be a valid long integer\"}");
            }
            return;
        }
        System.out.println("id=" + id + " eventId=" + eventId);

        if (arch == null && del == null) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            try (PrintWriter pw = response.getWriter()) {
                pw.write("{\"error\": \"either archive or delete parameter must be specified\"}");
            }
            return;
        } else if ((arch != null && del != null) && (Boolean.getBoolean(arch) && Boolean.getBoolean(del))) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            try (PrintWriter pw = response.getWriter()) {
                pw.write("{\"error\": \"only archive or delete flag can be set\"}");
            }
            return;
        }
        
        Boolean archive = Boolean.parseBoolean(arch);
        Boolean delete = Boolean.parseBoolean(del);

        WaveformService wfs = new WaveformService();
        try {
            // Cannot set an event to both be deleted and archived
            if (arch != null) {
                wfs.setEventArchiveFlag(eventId, archive);
                if ( archive == true) {
                    wfs.setEventDeleteFlag(eventId, false);
                }
            }
            // Cannot set an event to both be deleted and archived
            if (del != null) {
                wfs.setEventDeleteFlag(eventId, delete);
                if ( delete == true) {
                    wfs.setEventArchiveFlag(eventId, false);
                }
            }
        } catch (SQLException ex) {
            LOGGER.log(Level.WARNING, "Error updating database - {0}", ex.getMessage());
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            try (PrintWriter pw = response.getWriter()) {
                pw.write("{\"error\":\"Error updating the database - " + ex.getMessage() + "\"}");
            }
            return;
        }

        response.setStatus(HttpServletResponse.SC_OK);
        try (PrintWriter pw = response.getWriter()) {
            pw.write("{\"message\":\"Update successful\"}");
        }
    }

    /**
     * Returns a short description of the servlet.
     *
     * @return a String containing servlet description
     */
    @Override
    public String getServletInfo() {
        return "Short description";
    }// </editor-fold>

}
