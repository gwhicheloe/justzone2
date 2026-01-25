import Foundation

// TCX (Training Center XML) encoder - simpler than FIT and well-supported by Strava
enum TCXEncoder {
    static func encode(workout: Workout) -> Data {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Biking">
              <Id>\(dateFormatter.string(from: workout.startDate))</Id>
              <Lap StartTime="\(dateFormatter.string(from: workout.startDate))">
                <TotalTimeSeconds>\(workout.actualDuration)</TotalTimeSeconds>
                <DistanceMeters>0</DistanceMeters>
                <Calories>0</Calories>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>

        """

        // Add averages if available
        if let avgHR = workout.averageHeartRate {
            xml += "        <AverageHeartRateBpm><Value>\(avgHR)</Value></AverageHeartRateBpm>\n"
        }
        if let maxHR = workout.maxHeartRate {
            xml += "        <MaximumHeartRateBpm><Value>\(maxHR)</Value></MaximumHeartRateBpm>\n"
        }

        xml += "        <Track>\n"

        // Add trackpoints
        for sample in workout.samples {
            let sampleTime = workout.startDate.addingTimeInterval(sample.timestamp)
            xml += "          <Trackpoint>\n"
            xml += "            <Time>\(dateFormatter.string(from: sampleTime))</Time>\n"

            if let hr = sample.heartRate {
                xml += "            <HeartRateBpm><Value>\(hr)</Value></HeartRateBpm>\n"
            }

            if let power = sample.power {
                xml += """
                            <Extensions>
                              <TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                                <Watts>\(power)</Watts>
                              </TPX>
                            </Extensions>

                """
            }

            xml += "          </Trackpoint>\n"
        }

        xml += """
                </Track>
              </Lap>
              <Creator xsi:type="Device_t" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <Name>JustZone2</Name>
                <UnitId>0</UnitId>
                <ProductID>0</ProductID>
              </Creator>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """

        return xml.data(using: .utf8)!
    }
}

// Alternative: Simple FIT file encoder for future use if needed
// FIT format is more compact but TCX works well for our use case
enum FITEncoder {
    // FIT file structure constants
    private static let fitHeaderSize: UInt8 = 14
    private static let fitProtocolVersion: UInt8 = 0x20 // 2.0
    private static let fitProfileVersion: UInt16 = 2134 // 21.34

    // This is a placeholder for a more complete FIT encoder
    // For simplicity, we're using TCX which Strava accepts
    static func encode(workout: Workout) -> Data {
        // FIT encoding is complex - using TCX instead
        return TCXEncoder.encode(workout: workout)
    }
}
