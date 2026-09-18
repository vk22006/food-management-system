from salesforce import get_menu, get_order, get_delivery


def get_menu_tool():
    """Get the currently available QuickBite menu from Salesforce."""
    return get_menu()


def get_order_tool(order_name):
    """Get a QuickBite order using its order number."""
    return get_order(order_name)


def get_delivery_tool(order_name):
    """Get delivery tracking information for a QuickBite order."""
    return get_delivery(order_name)