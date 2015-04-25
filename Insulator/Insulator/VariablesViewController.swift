import UIKit
import HealthKit

class VariablesTableViewController: UITableViewController {
    
    let healthManager = HealthManager()
    let preferencesManager = PreferencesManager.sharedInstance
    
    @IBOutlet weak var currentBloodGlucoseLevelTextField: UITextField!
    @IBOutlet weak var carbohydratesInMealTextField: UITextField!
    @IBOutlet weak var correctiveDoseLabel: UILabel!
    @IBOutlet weak var carbohydrateDoseLabel: UILabel!
    @IBOutlet weak var suggestedDoseLabel: UILabel!
    @IBOutlet weak var rightBarButtonItem: UIBarButtonItem!
    
    @IBAction func openSettings(sender: AnyObject) {
        var settingsUrl = NSURL(string: UIApplicationOpenSettingsURLString, relativeToURL: nil)
        UIApplication.sharedApplication().openURL(settingsUrl!)
    }
    
    @IBAction func onRightBarButtonTouched(sender: AnyObject) {
        if carbohydratesInMealTextField.editing {
            carbohydratesInMealTextField.resignFirstResponder()
        } else if currentBloodGlucoseLevelTextField.editing {
            currentBloodGlucoseLevelTextField.resignFirstResponder()
        } else {
            clearFields()
        }
    }
    
    @IBAction func isHealthKitAuthorized(sender: UIButton) {
        healthManager.authoriseHealthKit { (authorized, error) -> Void in
            if authorized {
                println("HealthKit authorization received.")
                self.getDataFromHealthKit()
            } else {
                println("HealthKit authorization denied!")
                if error != nil {
                    println("\(error)")
                }
            }
        }
    }
    
    func getDataFromHealthKit() {
        let sampleType = HKSampleType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)
        
        healthManager.readMostRecentSample(sampleType, completion: { (mostRecentBloodGlucose, error) -> Void in
            if (error != nil) {
                println("Error reading blood glucose from HealthKit Store: \(error.localizedDescription)")
                return
            }
            
            let bloodGlucose: HKQuantitySample? = mostRecentBloodGlucose as? HKQuantitySample
            if let millgramsPerDeciliterOfBloodGlucose = bloodGlucose?.quantity.doubleValueForUnit(HKUnit(fromString: "mg/dL")) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    let bloodGlucoseUnit = self.preferencesManager.bloodGlucoseUnit
                    
                    // Maybe move this logic into the BloodGlucoseUnit type
                    // Would be nice to just call bloodGlucoseUnit.calculateFinalLevel(quantity)
                    let finalBloodGlucose: Double = {
                        switch bloodGlucoseUnit {
                        case .mmol: return Double(round((millgramsPerDeciliterOfBloodGlucose / 18) * 10) / 10)
                        case .mgdl: return Double(round(millgramsPerDeciliterOfBloodGlucose * 10) / 10)
                        }
                        }()
                    
                    self.currentBloodGlucoseLevelTextField.text = "\(finalBloodGlucose)"
                    self.attemptDoseCalculation()

                });
            }
            else {
                // No blood glucose quanity, so show no text
                self.currentBloodGlucoseLevelTextField.text = ""
            }
            
        });
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let build = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as? String {
            if preferencesManager.buildNumber != build {
                self.performSegueWithIdentifier("welcome", sender: AnyObject?())
            } else {
                updateBloodGlucoseUnitPlaceholder()
                
                currentBloodGlucoseLevelTextField.addTarget(self, action: "attemptDoseCalculation", forControlEvents: UIControlEvents.EditingChanged)
                currentBloodGlucoseLevelTextField.addTarget(self, action: "toggleRightBarButtonItem", forControlEvents: UIControlEvents.EditingDidBegin)
                currentBloodGlucoseLevelTextField.addTarget(self, action: "toggleRightBarButtonItem", forControlEvents: UIControlEvents.EditingDidEnd)
                carbohydratesInMealTextField.addTarget(self, action: "attemptDoseCalculation", forControlEvents: UIControlEvents.EditingChanged)
                carbohydratesInMealTextField.addTarget(self, action: "toggleRightBarButtonItem", forControlEvents: UIControlEvents.EditingDidBegin)
                carbohydratesInMealTextField.addTarget(self, action: "toggleRightBarButtonItem", forControlEvents: UIControlEvents.EditingDidEnd)
                
                self.navigationController?.toolbarHidden = false
                
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateBloodGlucoseUnitPlaceholder", name: PreferencesDidChangeNotification, object: nil)
            }
        }
    }

    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PreferencesDidChangeNotification, object: nil)
    }
    
    func toggleRightBarButtonItem() {
        if currentBloodGlucoseLevelTextField.editing || carbohydratesInMealTextField.editing {
            rightBarButtonItem.style = UIBarButtonItemStyle.Done
            rightBarButtonItem.title = "Done"
        } else {
            rightBarButtonItem.style = UIBarButtonItemStyle.Plain
            rightBarButtonItem.title = "Clear"
        }
    }
    
    func attemptDoseCalculation() {
        if let currentBloodGlucoseLevelText = currentBloodGlucoseLevelTextField.text {
            if let carbohydratesInMealText = carbohydratesInMealTextField.text {
                let bloodGlucoseLevel = (currentBloodGlucoseLevelText as NSString).doubleValue
                let carbohydrates = (carbohydratesInMealText as NSString).doubleValue
                
                calculateDose(currentBloodGlucoseLevel: bloodGlucoseLevel, carbohydratesInMeal: carbohydrates)
            }
        }
    }
    
    func calculateDose(#currentBloodGlucoseLevel: Double, carbohydratesInMeal: Double) {
        
        let calculator = Calculator(bloodGlucoseUnit: preferencesManager.bloodGlucoseUnit, carbohydrateFactor: preferencesManager.carbohydrateFactor, correctiveFactor: preferencesManager.correctiveFactor, desiredBloodGlucoseLevel: preferencesManager.desiredBloodGlucose, currentBloodGlucoseLevel: currentBloodGlucoseLevel, carbohydratesInMeal: carbohydratesInMeal)
        
        suggestedDoseLabel.text = "\(calculator.getSuggestedDose())"
        carbohydrateDoseLabel.text = "\(calculator.getCarbohydrateDose())"
        correctiveDoseLabel.text = "\(calculator.getCorrectiveDose())"
    }
    
    override func viewWillAppear(animated: Bool) {
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    
    func updateBloodGlucoseUnitPlaceholder() {
        let bloodGlucoseUnit = preferencesManager.bloodGlucoseUnit
        
        // TODO: Could you not just use .rawValue here?
        currentBloodGlucoseLevelTextField.placeholder = {
            switch bloodGlucoseUnit {
            case .mmol: return "mmol/L"
            case .mgdl: return "mg/dL"
            }
            }()
    }
    
    func clearFields() {
        currentBloodGlucoseLevelTextField.text = ""
        carbohydratesInMealTextField.text = ""
        suggestedDoseLabel.text = "0.0"
        carbohydrateDoseLabel.text = "0.0"
        correctiveDoseLabel.text = "0.0"
        
        self.view.endEditing(true)
    }

}