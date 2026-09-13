namespace DeliveryDisaster.Player
{
    /// <summary>Implemented by anything the player's vehicle can interact with on approach (pickup points, dropoff points, shops, checkpoints).</summary>
    public interface IInteractable
    {
        string InteractionPrompt { get; }
        bool CanInteract { get; }
        void Interact();
    }
}
