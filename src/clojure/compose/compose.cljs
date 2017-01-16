(ns compose.compose)

(enable-console-print!)

(defn process-v1 [compose] {:version "2", :services compose})

(defn process-v2 [compose] compose)

(defn process-compose [compose]
  (if-not (:version compose)
    (process-v1 compose)
    (process-v2 compose)))

(defn ^:export mapv2 [x] (clj->js (process-compose (js->clj x :keywordize-keys true))))
