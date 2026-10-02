package lab.order;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;

public class OrderHandler implements RequestHandler<SQSEvent, Void> {

    @Override
    public Void handleRequest(SQSEvent event, Context context) {

        context.getLogger().log("Order Service Lambda invoked\n");

        for (SQSEvent.SQSMessage message : event.getRecords()) {

            context.getLogger().log(
                    "SQS Message ID: " + message.getMessageId() + "\n"
            );

            context.getLogger().log(
                    "SQS Body: " + message.getBody() + "\n"
            );
        }

        return null;
    }
}