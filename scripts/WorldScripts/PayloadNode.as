namespace WorldScript
{
	[WorldScript color="255 180 170" icon="system/icons.png;416;128;32;32"]
	class PayloadNode
	{
		[Editable]
		UnitFeed NextNode;

		[Editable]
		bool Checkpoint;

		SValue@ ServerExecute()
		{
			return null;
		}
	}
}
