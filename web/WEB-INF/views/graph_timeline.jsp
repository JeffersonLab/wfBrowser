<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>
<%@taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions"%>
<%@taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt"%>
<%@taglib prefix="t" tagdir="/WEB-INF/tags"%> 
<c:set var="title" value="Graph"/>
<t:page title="${title}">  
    <jsp:attribute name="stylesheets">
        <link rel="stylesheet" href="${pageContext.request.contextPath}/resources/v${initParam.resourceVersionNumber}/css/dygraph.2.1.0.css" />
        <link rel="stylesheet" href="${pageContext.request.contextPath}/resources/v${initParam.resourceVersionNumber}/css/vis.min.css">

        <style>
            #timeline-container {
                border: 2px solid;
                padding: 1px;
                /* Settings for resizeable block
                                resize: vertical;
                                border: 2px solid;
                                padding: 10px;
                                overflow: auto;
                                min-height: 200px;*/
            }
            #graph-panel {
                text-align: center;
            }
            .graph-container {
                display: inline-block;
                border: 1px solid;
                padding: 2px;
                margin: 2px;
                height: 400px;
                width: 550px;
            }
            .graph-chart {
                float: left;
                height: 100%;
                width: 59%;
            }
            .graph-legend {
                float:right;
                height: 100%;
                width: 40%;
            }
            .graph-legend > span.highlight { border: 1px solid grey; }
            /*
            .few .graph-legend > span.highlight { border: 1px solid grey; }
                        .many .graph-legend > span { display: none; }
                        .many .graph-legend > span.highlight { display: inline; }
            */
        </style>
    </jsp:attribute>
    <jsp:attribute name="scripts">
        <script type="text/javascript" src="${pageContext.request.contextPath}/resources/v${initParam.resourceVersionNumber}/js/dygraph.2.1.0.min.js"></script>
        <script type="text/javascript" src="${pageContext.request.contextPath}/resources/v${initParam.resourceVersionNumber}/js/vis.min.js"></script>

        <script type="text/javascript">
            var $startPicker = $("#start-date-picker");
            var $endPicker = $("#end-date-picker");
            var $seriesSelector = $("#series-selector");
            var $zoneSelector = $("#zone-selector");
            var $graphPanel = $("#graph-panel");
            var firstUpdate = true;


            jlab.wfb.convertUTCDateStringToLocalDate = function (dateString) {
                var date = new Date(dateString);
                return new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(),
                        date.getMinutes(), date.getSeconds(), date.getMilliseconds()));
            };

            jlab.wfb.locationToGroupMap = new Map([
                ["0L04", 0],
                ["1L22", 1],
                ["1L23", 2],
                ["1L24", 3],
                ["1L25", 4],
                ["1L26", 5],
                ["2L22", 6],
                ["2L23", 7],
                ["2L24", 8],
                ["2L25", 9],
                ["2L26", 10]
            ]);

            // This takes an event JSON object (from ajax/event ajax query) and converts it to a form that is expected by visjs DataSet
            jlab.wfb.eventToItem = function (event) {
                var date = jlab.wfb.convertUTCDateStringToLocalDate(event.datetime_utc);
                var item = {
                    id: event.id,
                    content: "",
                    start: jlab.dateToDateTimeString(date),
                    group: jlab.wfb.locationToGroupMap.get(event.location)
                };
                return item;
            };


            // These get set by updateZoneSelector, and used by updateEventSelector
            var begin, end;

            /* 
             * eventId - The waveform eventId to query information for
             * chartId - typically a number, is appended to "graph-chart-" to create the id of a div that acts as the dygraph container
             * $graphPanel - jQuery object that is the parent object of all dygraph containers
             * graphOptions - set of dygraph graph options
             * series - the waveform event series name the display on this graph
             */
            jlab.wfb.makeGraph = function (eventId, chartId, $graphPanel, graphOptions, series) {
                if (typeof series === "undefied" || series === null) {
                    window.console && console.log("Required argument series not supplied to jlab.wfb.makeGraph");
                    return;
                }

                graphOptions.title = series;

                $graphPanel.append("<div class=graph-container><div id=graph-chart-" + chartId + " class='graph-chart'></div>"
                        + "<div class='graph-legend' id=graph-legend-" + chartId + " ></div></div>");
                graphOptions.labelsDiv = document.getElementById("graph-legend-" + chartId);
                var g = new Dygraph(
                        // containing div
                        document.getElementById("graph-chart-" + chartId),
                        "/wfbrowser/ajax/event?id=" + eventId + "&includeData=true&out=csv&series=" + series,
                        graphOptions
                        );

                // This event handler allows the users to highlight/unhighlight a single series
                var onclick = function (ev) {
                    if (g.isSeriesLocked()) {
                        g.clearSelection();
                    } else {
                        g.setSelection(g.getSelection(), g.getHighlightSeries(), true);
                    }
                };

                g.updateOptions({clickCallback: onclick}, true);
                g.setSelection(false, g.getHighlightSeries());
            };

            /*
             * Make all of the request waveform graphs.  One chart per series.
             * @param long eventId - The ID of the waveform event to graph
             * @param jQuery selector object $graphPanel The div in which to create waveform graphs
             * @param String[] series
             * @returns {undefined}
             */
            jlab.wfb.makeGraphs = function (eventId, $graphPanel, series) {
                var graphOptions = {
                    //                    height: 200,
                    //                    width: 400,
                    legend: "always",
//                        hideOverlayOnMouseOut: true,
//                        labelsSeparateLines: true,
                    highlightCircleSize: 2,
                    strokeWidth: 1,
//                        strokeBorderWidth: 1,
                    highlightSeriesOpts: {
                        strokeWidth: 2,
                        strokeBorderWidth: 1,
                        highlightCircleSize: 5
                    }
                };
                for (var i = 0; i < series.length; i++) {
                    jlab.wfb.makeGraph(eventId, i, $graphPanel, graphOptions, series[i]);
                }
            };

            jlab.wfb.updateBrowserUrlAndControls = function () {
                $startPicker.val(jlab.wfb.begin);
                $endPicker.val(jlab.wfb.end);

                // Update the URL so someone could navigate back to or bookmark or copy paste the URL 
                var url = "${pageContext.request.contextPath}/graph-timeline"
                        + "?start=" + jlab.wfb.begin.replace(/ /, '+').encodeXml()
                        + "&end=" + jlab.wfb.end.replace(/ /, '+').encodeXml()
                        + "&eventId=" + jlab.wfb.eventId;
                for (var i = 0; i < jlab.wfb.seriesSelections.length; i++) {
                    url += "&series=" + jlab.wfb.seriesSelections[i];
                }
                for (var i = 0; i < jlab.wfb.locationSelections.length; i++) {
                    url += "&location=" + jlab.wfb.locationSelections[i];
                }
                window.history.replaceState(null, null, url);
            };

            /*
             * Setup the timeline widget
             * begin  - starting datetime string of the timeline
             * end     - ending datetime string of the timeline
             * zones - array of zone names to be included in the timeline
             * events - array of events to be drawn
             */
//            jlab.wfb.makeTimeline = function (container, begin, end, zones, events, eventId) {
            jlab.wfb.makeTimeline = function (container, zones, events) {

                var groupArray = new Array(zones.length);
                for (var i = 0; i < zones.length; i++) {
                    groupArray[i] = {id: jlab.wfb.locationToGroupMap.get(zones[i]), content: zones[i]};
                }
                var groups = new vis.DataSet(groupArray);

                var itemArray = new Array(events.length);
                for (var i = 0; i < events.length; i++) {
                    itemArray[i] = jlab.wfb.eventToItem(events[i]);
                }
                var items = new vis.DataSet(itemArray);

                var options = {
                    start: jlab.wfb.begin,
                    end: jlab.wfb.end,
                    stack: false,
                    selectable: true,
                    multiselect: false
//                    moveable: false
//                    verticalScroll: true,
//                    zoomKey: 'ctrlKey',
                    //                    minHeight: "200px",
                    //                    height: "100%"
                };

                var timeline = new vis.Timeline(container, items, groups, options);
                if (typeof jlab.wfb.eventId !== "undefined" && jlab.wfb.eventId !== null) {
                    timeline.setSelection(jlab.wfb.eventId);
                }
                timeline.on("rangechanged", function (params) {
                    var timeLineStart = params.start;
                    var timeLineEnd = params.end;
                    var byUser = params.byUser;
                    var event = params.event;
                    var queryStart = timeLineStart;
                    var queryEnd = timeline.getItemRange().min || timeLineEnd;  // In case the current timeline window has no data associated with it
                    jlab.wfb.begin = jlab.dateToDateTimeString(timeLineStart);
                    jlab.wfb.end = jlab.dateToDateTimeString(timeLineEnd);

                    if (byUser) {
                        jlab.wfb.updateBrowserUrlAndControls();

                        var url = jlab.contextPath + "/ajax/event";
                        var data = {
                            begin: jlab.dateToDateTimeString(queryStart),
                            end: jlab.dateToDateTimeString(queryEnd),
                            location: jlab.wfb.locationSelections};
                        var settings = {
                            "url": url,
                            type: "GET",
                            traditional: true,
                            "data": data,
                            dataType: "json"
                        };
                        var promise = $.ajax(settings);

                        // Basically copy and paste of the smoothness doAjaxJsonGetRequest error handler.
                        // Done since I needed to be able to pass the "traditional" setting
                        promise.error(function (xhr, textStatus) {
                            var json;

                            try {
                                json = $.parseJSON(xhr.responseText);
                            } catch (err) {
                                window.console && console.log('Response is not JSON: ' + xhr.responseText);
                                json = {};
                            }

                            var message = json.error || 'Server did not handle request';
                            alert('Unable to perform request: ' + message);
                        });

                        promise.done(function (json) {
                            var eventArray = json.events;
                            var newItems = new Array(eventArray.length);
                            for (var i = 0; i < eventArray.length; i++) {
                                newItems[i] = jlab.wfb.eventToItem(eventArray[i]);
                            }
                            items.add(newItems);
                        });
                    }
                });

                timeline.on("select", function (params) {
                    jlab.wfb.eventId = params.items[0];
                    jlab.wfb.updateBrowserUrlAndControls();
                    $graphPanel.html("");
                    jlab.wfb.makeGraphs(jlab.wfb.eventId, $graphPanel, jlab.wfb.seriesSelections);
                });
            };


            $(function () {
                $seriesSelector.select2();
                $zoneSelector.select2();
                $startPicker.val(jlab.wfb.begin);
                $endPicker.val(jlab.wfb.end);
                $(".date-time-field").datetimepicker({
                    controlType: jlab.dateTimePickerControl,
                    dateFormat: 'yy-mm-dd',
                    timeFormat: 'HH:mm:ss'
                });

                var timelineDiv = document.getElementById("timeline-container");
                jlab.wfb.makeTimeline(timelineDiv, jlab.wfb.locationSelections, jlab.wfb.eventArray);

                if (typeof jlab.wfb.eventId !== "undefined" && jlab.wfb.eventId !== null && jlab.wfb.eventId !== "") {
                    jlab.wfb.makeGraphs(jlab.wfb.eventId, $graphPanel, jlab.wfb.seriesSelections);
                }
            });
        </script>
    </jsp:attribute>
    <jsp:body>
        <section>
            <h2 id="page-header-title"><c:out value="${title}"/></h2>
            <div id="timeline-container"></div>
            <form method="GET" action="${pageContext.request.contextPath}/graph-timeline">
                <ul class="key-value-list">
                    <li>
                        <div class="li-key"><label class="required-field" for="begin">Start</label></div>
                        <div class="li-value"><input type="text" id="start-date-picker" class="date-time-field" name="begin" placeholder="yyyy-mm-dd HH:mm:ss.S"/></div>
                    </li>
                    <li>
                        <div class="li-key"><label class="required-field" for="end">End</label></div>
                        <div class="li-value"><input type="text" id="end-date-picker" class="date-time-field" name="end" placeholder="yyyy-mm-dd HH:mm:ss.S"/></div>
                    </li>
                    <li>
                        <div class="li-key"><label class="required-field" for="locations">Zone</label></div>
                        <div class="li-value">
                            <select id="zone-selector" name="location" multiple>
                                <c:forEach var="location" items="${requestScope.locationMap}">
                                    <option value="${location.key}" label="${location.key}" <c:if test="${location.value}">selected</c:if>>${location.key}</option>
                                </c:forEach>
                            </select>
                        </div>
                    </li>
                    <li>
                        <div class="li-key"><label class="required-field" for="series">Series</label></div>
                        <div class="li-value">
                            <select id="series-selector" name="series" multiple>
                                <c:forEach var="series" items="${requestScope.seriesMap}">
                                    <option value="${series.key}" label="${series.key}" <c:if test="${series.value}">selected</c:if>>${series.key}</option>
                                </c:forEach>
                            </select>
                        </div>
                    </li>
                </ul>
                <input type="submit"/>
            </form>
            <div id="graph-panel" style="width:100%;"></div>
        </section>
        <script>
            var jlab = jlab || {};
            jlab.wfb = jlab.wfb || {};
            jlab.wfb.eventId = "${requestScope.eventId}";
                    jlab.wfb.locationSelections = [<c:forEach var="location" items="${locationSelections}" varStatus="status">'${location}'<c:if test="${!status.last}">,</c:if></c:forEach>];
            jlab.wfb.begin = "${requestScope.begin}";
            jlab.wfb.end = "${requestScope.end}";
            jlab.wfb.eventArray = ${requestScope.eventListJson};
            jlab.wfb.eventArray = jlab.wfb.eventArray.events;
                    jlab.wfb.seriesSelections = [<c:forEach var="series" items="${seriesSelections}" varStatus="status">'${series}'<c:if test="${!status.last}">,</c:if></c:forEach>];
                </script>
    </jsp:body>  
</t:page>