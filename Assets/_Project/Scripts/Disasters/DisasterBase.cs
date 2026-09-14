using UnityEngine;

namespace DeliveryDisaster.Disasters
{
    /// <summary>
    /// Base class for every disaster. Handles the shared plumbing (definition,
    /// spawn location, difficulty, self-destruction) so concrete disasters only
    /// implement their actual gameplay effect via the OnTelegraph/OnActivate/OnCleanup hooks.
    /// </summary>
    public abstract class DisasterBase : MonoBehaviour, IDisaster
    {
        protected DisasterDefinition Definition { get; private set; }
        protected Vector3 SpawnLocation { get; private set; }
        protected float Difficulty { get; private set; }

        [Tooltip("Extra seconds to keep this GameObject alive after Cleanup, e.g. for a fade-out VFX.")]
        [SerializeField] protected float destroyDelayAfterCleanup = 1.5f;

        public void Setup(DisasterDefinition definition, Vector3 location, float difficulty)
        {
            Definition = definition;
            SpawnLocation = location;
            Difficulty = difficulty;
            transform.position = location;
        }

        public void Telegraph() => OnTelegraph();
        public void Activate() => OnActivate();

        public void Cleanup()
        {
            OnCleanup();
            Destroy(gameObject, destroyDelayAfterCleanup);
        }

        /// <summary>Warning phase - show an indicator, play a warning sound cue, etc. No gameplay effect yet.</summary>
        protected abstract void OnTelegraph();

        /// <summary>Effect begins - spawn hazards, apply forces, damage, etc.</summary>
        protected abstract void OnActivate();

        /// <summary>Effect ends - stop damaging, despawn hazards, restore any world state that was changed.</summary>
        protected abstract void OnCleanup();

        /// <summary>
        /// Convenience for disasters used before final art exists: spawns a simple
        /// primitive so the disaster is visible/testable with zero external assets.
        /// </summary>
        protected GameObject SpawnPlaceholderVisual(PrimitiveType type, Vector3 localScale, Color color, Transform parent = null)
        {
            var go = GameObject.CreatePrimitive(type);
            go.transform.SetParent(parent != null ? parent : transform, false);
            go.transform.localScale = localScale;
            go.transform.localPosition = Vector3.zero;

            var renderer = go.GetComponent<Renderer>();
            if (renderer != null)
            {
                var mat = new Material(Shader.Find("Standard"));
                mat.color = color;
                renderer.material = mat;
            }

            return go;
        }

        /// <summary>Finds the player's vehicle transform if one exists in the scene, otherwise null.</summary>
        protected Transform FindPlayerTransform()
        {
            return Player.PlayerReference.Active != null ? Player.PlayerReference.Active.transform : null;
        }
    }
}
