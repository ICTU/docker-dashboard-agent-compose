(defproject bigboat-agent-compose "0.1.0-SNAPSHOT"
  :description "An agent implementation for Big Boat based on Docker Compose"
  :url "http://example.com/FIXME"
  :dependencies [[org.clojure/clojure "1.8.0"]
                 [org.clojure/clojurescript "1.9.293"]]
  :jvm-opts ^:replace ["-Xmx1g" "-server"]
  :plugins [[lein-npm "0.6.1"]
            [lein-cljsbuild "1.1.5"]]
  :npm {:dependencies [[source-map-support "0.4.0"]
                       [lodash "4.17.4"]]}
  :source-paths ["src/clojure" "target/classes"]
  :clean-targets ["out" "release"]
  :target-path "target"

  :cljsbuild
  { :builds
    [{:id "simple"
      :source-paths ["clojure"]
      :compiler
      { :output-dir "out"
        :optimizations :none
        :cache-analysis true
        :source-map true
        :verbose true
        :output-wrapper false
        :target :nodejs
        :modules
        { :compose
          { :output-to "out/compose/compose.js"
            :entries #{"compose.compose"}}}}}]})
