import Foundation

enum BloodGlucoseUnit: String  {
    case mmol = "mmol"
    case mgdl = "mgdl"
    
    static func fromString(string: String) -> BloodGlucoseUnit? {
        switch string {
        case BloodGlucoseUnit.mmol.rawValue: return .mmol
        case BloodGlucoseUnit.mgdl.rawValue: return .mgdl
        default: return nil
        }
    }
    
    static func defaultUnit () -> BloodGlucoseUnit { return BloodGlucoseUnit.mmol }
}


class Calculator {
    let carbohydrateFactor: Double
    let correctiveFactor: Double
    let desiredBloodGlucoseLevel: Double
    let currentBloodGlucoseLevel: Double
    let carbohydratesInMeal: Double
    let bloodGlucoseUnit: BloodGlucoseUnit
    
    init(carbohydrateFactor: Double, correctiveFactor: Double, desiredBloodGlucoseLevel: Double, currentBloodGlucoseLevel: Double, carbohydratesInMeal: Double, bloodGlucoseUnit: BloodGlucoseUnit) {
        self.carbohydrateFactor = carbohydrateFactor
        self.correctiveFactor = correctiveFactor
        self.desiredBloodGlucoseLevel = desiredBloodGlucoseLevel
        self.currentBloodGlucoseLevel = currentBloodGlucoseLevel
        self.carbohydratesInMeal = carbohydratesInMeal
        self.bloodGlucoseUnit = bloodGlucoseUnit
    }
    
    func convertBloodGlucose(bloodGlucose: Double) -> Double {
        
        switch bloodGlucoseUnit {
        case .mmol:
            return bloodGlucose
        case .mgdl:
            return bloodGlucose / 18
        }
    }
    
    func getCarbohydrateDose() -> Double {
        var carbohydrateDose = 0.0
        
        if carbohydrateFactor != 0 {
            carbohydrateDose = carbohydratesInMeal / carbohydrateFactor
        }
        
        return carbohydrateDose
    }
    
    func getCorrectiveDose() -> Double {
        var correctiveDose = 0.0
        
        if currentBloodGlucoseLevel != 0 {
            correctiveDose = (convertBloodGlucose(currentBloodGlucoseLevel) - convertBloodGlucose(desiredBloodGlucoseLevel)) / correctiveFactor
        }
        
        return correctiveDose
    }
    
    func getSuggestedDose() -> Double {
        var suggestedDose = getCarbohydrateDose() + getCorrectiveDose()
        
        if suggestedDose < 0 {
            suggestedDose = 0
        }
        
        return suggestedDose
    }
}