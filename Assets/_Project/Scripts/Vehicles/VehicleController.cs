using System;
using UnityEngine;
using DeliveryDisaster.Input;
using DeliveryDisaster.Economy;
using DeliveryDisaster.Core;

namespace DeliveryDisaster.Vehicles
{
    [RequireComponent(typeof(Rigidbody))]
    public class VehicleController : MonoBehaviour
    {
        [Header("Wheels")]
        [SerializeField] private WheelCollider frontLeft;
        [SerializeField] private WheelCollider frontRight;
        [SerializeField] private WheelCollider rearLeft;
        [SerializeField] private WheelCollider rearRight;

        [Header("Wheel Visuals (optional, purely cosmetic)")]
        [SerializeField] private Transform frontLeftVisual;
        [SerializeField] private Transform frontRightVisual;
        [SerializeField] private Transform rearLeftVisual;
        [SerializeField] private Transform rearRightVisual;

        [Header("Config")]
        [SerializeField] private VehicleData vehicleData;
        [SerializeField] private Transform centerOfMass;

        private Rigidbody rb;
        private VehicleDamageSystem damageSystem;

        private float motorTorque;
        private float maxSteerAngle;
        private float brakeTorque;

        public float CurrentSpeedKph { get; private set; }
        public float EngineLoad01 { get; private set; } // 0..1, used by audio for engine pitch
        public bool IsBrokenDown { get; private set; }
        public bool ControlsEnabled { get; set; } = true;

        /// <summary>Multiplies all handling/braking response - disasters (flood, ice, debris) drive this down temporarily.</summary>
        public float TractionMultiplier { get; set; } = 1f;

        public event Action<float> OnSpeedChanged;

        private void Awake()
        {
            rb = GetComponent<Rigidbody>();
            damageSystem = GetComponent<VehicleDamageSystem>();

            if (centerOfMass != null)
            {
                rb.centerOfMass = transform.InverseTransformPoint(centerOfMass.position);
            }

            ApplyVehicleData();
        }

        private void OnEnable()
        {
            EventBus.Subscribe<VehicleBrokeDownEvent>(OnBrokeDown);
        }

        private void OnDisable()
        {
            EventBus.Unsubscribe<VehicleBrokeDownEvent>(OnBrokeDown);
        }

        private void ApplyVehicleData()
        {
            if (vehicleData == null) return;

            float engineUpgrade = UnlockManager.Instance != null ? UnlockManager.Instance.GetTotalUpgradeEffect(UpgradeType.EngineSpeed) : 0f;
            float handlingUpgrade = UnlockManager.Instance != null ? UnlockManager.Instance.GetTotalUpgradeEffect(UpgradeType.Handling) : 0f;

            motorTorque = vehicleData.BaseMotorTorque * (1f + engineUpgrade);
            maxSteerAngle = vehicleData.BaseMaxSteerAngle * (1f + handlingUpgrade);
            brakeTorque = vehicleData.BaseBrakeTorque;
        }

        private void FixedUpdate()
        {
            CurrentSpeedKph = rb.velocity.magnitude * 3.6f;
            OnSpeedChanged?.Invoke(CurrentSpeedKph);

            if (!ControlsEnabled || IsBrokenDown)
            {
                ApplyBraking(brakeTorque);
                EngineLoad01 = 0f;
                return;
            }

            var input = InputService.Current;
            float steer = input.Steer * maxSteerAngle;
            float throttle = input.Throttle;
            bool handbrake = input.HandbrakePressed;

            frontLeft.steerAngle = steer;
            frontRight.steerAngle = steer;

            float appliedTorque = throttle * motorTorque * TractionMultiplier;
            rearLeft.motorTorque = appliedTorque;
            rearRight.motorTorque = appliedTorque;
            frontLeft.motorTorque = 0f; // rear-wheel drive by default; adjust per-vehicle if adding AWD

            EngineLoad01 = Mathf.Clamp01(Mathf.Abs(throttle));

            if (handbrake)
            {
                ApplyBraking(brakeTorque * 2f);
            }
            else
            {
                float coastBrake = Mathf.Approximately(throttle, 0f) ? brakeTorque * 0.15f : 0f;
                ApplyBraking(coastBrake);
            }

            UpdateWheelVisual(frontLeft, frontLeftVisual);
            UpdateWheelVisual(frontRight, frontRightVisual);
            UpdateWheelVisual(rearLeft, rearLeftVisual);
            UpdateWheelVisual(rearRight, rearRightVisual);
        }

        private void ApplyBraking(float torque)
        {
            frontLeft.brakeTorque = torque;
            frontRight.brakeTorque = torque;
            rearLeft.brakeTorque = torque;
            rearRight.brakeTorque = torque;
        }

        private static void UpdateWheelVisual(WheelCollider collider, Transform visual)
        {
            if (visual == null) return;
            collider.GetWorldPose(out var pos, out var rot);
            visual.SetPositionAndRotation(pos, rot);
        }

        private void OnBrokeDown(VehicleBrokeDownEvent evt) => IsBrokenDown = true;

        /// <summary>Called by disaster/repair logic to force a temporary breakdown (e.g. vehicle explosion nearby) and later clear it.</summary>
        public void SetBrokenDown(bool brokenDown)
        {
            IsBrokenDown = brokenDown;
            if (brokenDown) EventBus.Publish(new VehicleBrokeDownEvent());
        }

        public void ApplyImpulse(Vector3 force, ForceMode mode = ForceMode.Impulse) => rb.AddForce(force, mode);

        public void ApplyTorqueImpulse(Vector3 torque, ForceMode mode = ForceMode.Impulse) => rb.AddTorque(torque, mode);
    }
}
