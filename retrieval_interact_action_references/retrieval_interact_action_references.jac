import:py logging;
import:py traceback;
import:py from logging { Logger }
import:jac from jivas.agent.action.actions { Actions }
import:jac from jivas.agent.action.interact_action { InteractAction }
import:jac from jivas.agent.action.interact_graph_walker { interact_graph_walker }
import:jac from jivas.agent.action.retrieval_interact_action { RetrievalInteractAction }
import:jac from jivas.agent.memory.interaction_response { TextInteractionMessage, SilentInteractionMessage }


node RetrievalInteractActionReferences :InteractAction: {
    # manages phoneme-based prompting to customize the pronunciation of certain words for text-to-speech models used by an agent
    # always ensure that this is registered after the final response is generated

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    has model_action: str = "LangChainModelAction";
    has model_name: str = "gpt-4o";
    has model_max_tokens:int = 4096;
    has model_temperature: float = 0.0;
    has history: bool = True;
    has history_size: int = 1;
    has max_statement_length: int = 2048;
    has prompt: str = """
Analyze the UTTERANCE, RESPONSE, and CONTEXT. Identify and return all relevant references from the CONTEXT that support the information in the RESPONSE.

Instructions:
- For each supporting item in CONTEXT, extract the corresponding reference(s) using the fields specified in REF_FIELDS.
- Format each reference according to the pattern defined in REF_FORMAT.
- Ensure all returned references are unique.
- If no references in CONTEXT support the RESPONSE, return an empty list.

Inputs:
UTTERANCE:
{utterance}

RESPONSE:
{response}

CONTEXT:
{context}

REF_FIELDS:
{ref_fields}

REF_FORMAT:
{ref_format}

Output:
Return a JSON object containing the "references". The "references" field should be list of strings.
""";
    # the field or fields (comma separated) in the metadata to use for crafting the references
    has metadata_ref_fields:str = "source, filename, page";
    # an example format used for formatting the references based on the metadata_ref_fields
    has metadata_ref_format:str = "( [filename](source), pp. <page>; [filename](source), pp. <page>; ... )";

    can post_register() {
        # to ensure compatibility, add this action to the exception list in intent_classifier
        if(intent_interact_action_node := self.get_agent().get_actions().get(action_label='IntentInteractAction')) {
            if(self.get_type() not in intent_interact_action_node.exceptions) {
                intent_interact_action_node.exceptions += [self.get_type()];
            }
        }

        self.get_agent().get_actions() spawn _configure_retrieval_action();

    }

    can touch(visitor: interact_graph_walker) -> bool {
        if(visitor.interaction_node.has_response() and visitor.interaction_node.context_data.get('RetrievalInteractAction_context')) {
            return True;
        }
    }

    can execute(visitor: interact_graph_walker) -> dict {
        utterance = visitor.interaction_node.context_data.get('RetrievalInteractAction_query', '');
        context_json = visitor.interaction_node.context_data.get('RetrievalInteractAction_context', []);
        response = visitor.interaction_node.response.get('message', {}).get('content', '');
        try {
            if (utterance and context_json) {
                if "metadata" in context_json[0] {
                    prompt_messages = [{"system": self.prompt}];
                    prompt_variables = {
                        "ref_fields": self.metadata_ref_fields,
                        "ref_format": self.metadata_ref_format,
                        "context": context_json,
                        "response": response,
                        "utterance": utterance
                    };

                    model_action = self.get_agent().get_action(action_label=self.model_action);
                    if model_action {
                        model_action_result = model_action.call_model(
                            prompt_messages=prompt_messages,
                            prompt_variables=prompt_variables,
                            kwargs={
                                "model_name": self.model_name,
                                "model_temperature": self.model_temperature,
                                "model_max_tokens": self.model_max_tokens
                            },
                            interaction_node=visitor.interaction_node
                        );

                        if model_action_result {
                            result = model_action_result.get_json_result();
                            if (result.get("references")) {
                                references = "\n".join(result["references"]);
                                response += "\n\nReferences:\n" + references;
                                visitor.interaction_node.set_message(TextInteractionMessage(content=response));
                            }
                        }
                    }
                }
            }
        } except Exception as e {
            self.logger.warning("Unable to add references to response");
        }
    }


    can healthcheck() -> Union[bool, dict] {

        test_prompt_messages = [{"system" : "Output the result of 2 + 2"}];
        test_kwargs = {
            "model_name": self.model_name,
            "model_temperature": self.model_temperature,
            "model_max_tokens": self.model_max_tokens
        };

        try {
            model_action = self.get_agent().get_action(action_label=self.model_action);
            if( model_action_result := model_action.call_model(prompt_messages = test_prompt_messages, prompt_variables = {}, kwargs = test_kwargs)) {               # set the interaction message+
                interaction_message = model_action_result.get_result();
                if not interaction_message {
                    return {
                        "status": False,
                        "message": "No valid result from LLM call. Check API key and model configuration.",
                        "severity": "error"
                    };
                } else {
                    return True;
                }
            }
            return {
                "status": False,
                "message": "Unable to excute LLM call. Check API key and model configuration.",
                "severity": "error"
            };
        } except Exception as e {
            self.logger.error(f"An exception occurred in {self.label}:\n{traceback.format_exc()}\n");
            return {
                "status": False,
                "message": f"There is an issue with the action. {e}",
                "severity": "error"
            };
        }
    }
}



walker _configure_retrieval_action {

    obj __specs__ {
        static has private: bool = True;
    }

    can on_actions with Actions entry {
        visit [-->](`?RetrievalInteractAction);
    }

    can on_action with RetrievalInteractAction entry {
        here.metadata = True;
    }

}

