(ns compose.compose)

(enable-console-print!)

(defn v2dot1 [services] {:version "2.1", :services services})

(defn process-with-version [compose] (v2dot1 (services compose)))

(defn services [compose]
  (if-not (:services compose)
    compose
    (:services compose)))

(defn process-compose [compose]
  (if-not (:version compose)
    (v2dot1 compose)
    (process-with-version compose)))

(defn ^:export mapv2 [x] (clj->js (process-compose (js->clj x :keywordize-keys true))))
