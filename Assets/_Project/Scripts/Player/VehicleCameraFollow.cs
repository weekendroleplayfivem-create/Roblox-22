using UnityEngine;

namespace DeliveryDisaster.Player
{
    /// <summary>Simple third-person chase camera with spring-damped follow/look. Attach to the Main Camera.</summary>
    public class VehicleCameraFollow : MonoBehaviour
    {
        [SerializeField] private Vector3 offset = new Vector3(0f, 4.5f, -8.5f);
        [SerializeField] private float positionSmoothTime = 0.15f;
        [SerializeField] private float rotationSpeed = 6f;
        [SerializeField] private float lookAheadHeight = 1.2f;

        private Transform target;
        private Vector3 velocity;

        public void SetTarget(Transform newTarget) => target = newTarget;

        private void LateUpdate()
        {
            if (target == null) return;

            Vector3 desiredPosition = target.TransformPoint(offset);
            transform.position = Vector3.SmoothDamp(transform.position, desiredPosition, ref velocity, positionSmoothTime);

            Vector3 lookPoint = target.position + Vector3.up * lookAheadHeight;
            Quaternion desiredRotation = Quaternion.LookRotation((lookPoint - transform.position).normalized, Vector3.up);
            transform.rotation = Quaternion.Slerp(transform.rotation, desiredRotation, rotationSpeed * Time.deltaTime);
        }
    }
}
