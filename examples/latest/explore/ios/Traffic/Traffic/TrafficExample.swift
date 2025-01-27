/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import heresdk
import UIKit

class TrafficExample: TapDelegate {

    private var viewController: UIViewController
    private var mapView: MapView
    private var trafficEngine: TrafficEngine
    // Visualizes traffic incidents found with the TrafficEngine.
    private var mapPolylineList = [MapPolyline]()
    private var tappedGeoCoordinates: GeoCoordinates = GeoCoordinates(latitude: -1, longitude: -1)

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      distanceInMeters: 1000 * 10)

        do {
            try trafficEngine = TrafficEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize TrafficEngine. Cause: \(engineInstantiationError)")
        }

        // Setting a tap handler to search for traffic incidents around the tapped area.
        mapView.gestures.tapDelegate = self

        showDialog(title: "Note",
                   message: "Tap on the map to search for traffic incidents.")
    }

    func onEnableAllButtonClicked() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization()
    }

    func onDisableAllButtonClicked() {
        disableTrafficVisualization()
    }

    private func enableTrafficVisualization() {
        // Once these layers are added to the map, they will be automatically updated while panning the map.
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.trafficFlow, visibility: VisibilityState.visible)
        // MapScene.Layers.trafficIncidents renders traffic icons and lines to indicate the location of incidents. Note that these are not directly pickable yet.
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.trafficIncidents, visibility: VisibilityState.visible)
    }

    private func disableTrafficVisualization() {
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.trafficFlow, visibility: VisibilityState.hidden)
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.trafficIncidents, visibility: VisibilityState.hidden)

        // This clears only the custom visualization for incidents found with the TrafficEngine.
        clearTrafficIncidentsMapPolylines()
    }

    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        if let touchGeoCoords = mapView.viewToGeoCoordinates(viewCoordinates: origin) {
            tappedGeoCoordinates = touchGeoCoords
            queryForIncidents(centerCoords: tappedGeoCoordinates)
        }
    }

    private func queryForIncidents(centerCoords: GeoCoordinates) {
        let geoCircle = GeoCircle(center: centerCoords, radiusInMeters: 1000)
        let trafficIncidentsQueryOptions = TrafficIncidentsQueryOptions()
        // Optionally, specify a language:
        // If the language is not supported, then the default behavior is applied and
        // the language of the country where the incident occurs is used.
        // trafficIncidentsQueryOptions.languageCode = LanguageCode.enUs
        trafficEngine.queryForIncidents(inside: geoCircle,
                                        queryOptions: trafficIncidentsQueryOptions,
                                        completion: onTrafficIncidentsFound);
    }

    // TrafficIncidentQueryCompletionHandler to receive traffic items.
    func onTrafficIncidentsFound(error: TrafficQueryError?,
                                 trafficIncidentsList: [TrafficIncident]?) {
        if let trafficQueryError = error {
            print("TrafficQueryError: \(trafficQueryError)")
            return
        }

        // If error is nil, it is guaranteed that the list will not be nil.
        var trafficMessage = "Found \(trafficIncidentsList!.count) result(s). See log for details."
        let nearestIncident = getNearestTrafficIncident(currentGeoCoords: tappedGeoCoordinates,
                                                        trafficIncidentsList: trafficIncidentsList!)
        trafficMessage.append(contentsOf: " Nearest incident: \(nearestIncident?.description.text ?? "nil")")
        showDialog(title: "Nearby traffic incidents",
                   message: trafficMessage)

        for trafficIncident in trafficIncidentsList! {
            print(trafficIncident.description.text)
            addTrafficIncidentsMapPolyline(geoPolyline: trafficIncident.location.polyline)
        }
    }

    private func getNearestTrafficIncident(currentGeoCoords: GeoCoordinates,
                                           trafficIncidentsList: [TrafficIncident]) -> TrafficIncident? {
        if trafficIncidentsList.count == 0 {
            return nil
        }

        // By default, traffic incidents results are not sorted by distance.
        var nearestDistance: Double = Double.infinity
        var nearestTrafficIncident: TrafficIncident!
        for trafficIncident in trafficIncidentsList {
            // In case lengthInMeters == 0 then the polyline consistes of two equal coordinates.
            // It is guaranteed that each incident has a valid polyline.
            for geoCoords in trafficIncident.location.polyline.vertices {
                let currentDistance = currentGeoCoords.distance(to: geoCoords)
                if currentDistance < nearestDistance {
                    nearestDistance = currentDistance
                    nearestTrafficIncident = trafficIncident
                }
            }
        }

        return nearestTrafficIncident
    }

    private func addTrafficIncidentsMapPolyline(geoPolyline: GeoPolyline) {
        // Show traffic incident as polyline.
        let mapPolyline = MapPolyline(geometry: geoPolyline,
                                      widthInPixels: 20,
                                      color: UIColor(red: 0,
                                                     green: 0,
                                                     blue: 0,
                                                     alpha: 0.5))
        mapView.mapScene.addMapPolyline(mapPolyline)
        mapPolylineList.append(mapPolyline)
    }

    private func clearTrafficIncidentsMapPolylines() {
        for mapPolyline in mapPolylineList {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylineList.removeAll()
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
