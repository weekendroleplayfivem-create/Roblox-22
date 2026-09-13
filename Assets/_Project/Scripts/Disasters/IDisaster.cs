using UnityEngine;

namespace DeliveryDisaster.Disasters
{
    /// <summary>
    /// Lifecycle every disaster implements. DisasterManager drives these calls in
    /// order: Setup -> Telegraph (warning phase) -> Activate (effect begins) ->
    /// Cleanup (effect ends, difficulty scaling applied throughout via Setup).
    /// </summary>
    public interface IDisaster
    {
        void Setup(DisasterDefinition definition, Vector3 location, float difficulty);
        void Telegraph();
        void Activate();
        void Cleanup();
    }
}
