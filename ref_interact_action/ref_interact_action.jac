import logging;
import traceback;
import from logging { Logger }
import from jivas.agent.action.actions { Actions }
import from jivas.agent.action.interact_action { InteractAction }
import from jivas.agent.action.agent_graph_walker { agent_graph_walker }
import from jivas.agent.action.retrieval_interact_action { RetrievalInteractAction }
import from jivas.agent.memory.interaction_response { InteractionMessage, TextInteractionMessage, SilentInteractionMessage }


node RefInteractAction(InteractAction) {
    # manages phoneme-based prompting to customize the pronunciation of certain words for text-to-speech models used by an agent
    # always ensure that this is registered after the final response is generated

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    has retrieval_interact_action: str = "TypesenseRetrievalInteractAction";
    has model_action: str = "LangChainModelAction";
    has model_name: str = "gpt-4o";
    has model_max_tokens:int = 4096;
    has model_temperature: float = 0.0;
    has channel_format_directives: dict = {
        "facebook": (
            "Structure Facebook content with these formatting rules:\n"
            "- Italic: Wrap text with underscores (_text_)\n"
            "- Bold: Wrap text with asterisks (*text*)\n"
            "- Strikethrough: Wrap text with tildes (~text~)\n"
            "- URLs: Display URLs as-is, no markdown formatting.\n"
            "- Separate paragraphs with line breaks"
        ),

        "whatsapp": (
            "Structure WhatsApp messages with these rules:\n"
            "- Italic: Surround with underscores (_text_)\n"
            "- Bold: Surround with asterisks (*text*)\n"
            "- Strikethrough: Surround with tildes (~text~)\n"
            "- Bullet lists: Start lines with * or -\n"
            "- Numbered lists: Begin with 1. 2. 3.\n"
            "- Quotes: Prefix lines with > symbol\n"
            "- URLs: Display URLs as-is, no markdown formatting.\n"
            "- Separate sections with line breaks"
        ),

        "instagram": (
            "Structure Instagram content with:\n"
            "- Bold: Surround text with asterisks (*text*)\n"
            "- Italic: Surround text with underscores (_text_)\n"
            "- URLs: Display URLs as-is, no markdown formatting.\n"
            "- Use single line breaks between paragraphs\n"
            "- Maximum 30 hashtags at caption end"
        ),

        "twitter": (
            "Structure Twitter/X posts with:\n"
            "- Bold: Use asterisks (*text*)\n"
            "- Italic: Use underscores (_text_)\n"
            "- URLs: Display URLs as-is, no markdown formatting.\n"
            "- Threads: Start with (1/3) indicator\n"
            "- Keep under 280 characters per tweet"
        ),

        "linkedin": (
            "Structure LinkedIn posts with:\n"
            "- Bold: Asterisks around text (*text*)\n"
            "- Italic: Underscores around text (_text_)\n"
            "- Bullets: Start lines with * or -\n"
            "- URLs: Display URLs as-is, no markdown formatting.\n"
            "- Sections: Separate with --- on own line\n"
            "- Paragraphs: Maximum 5 lines each"
        ),

        "email": (
            "Structure emails with:\n"
            "- Bold: Surround with asterisks (*important*)\n"
            "- Italic: Surround with underscores (_emphasis_)\n"
            "- Lists: Use * or - for bullet points\n"
            "- Quotes: Begin lines with > symbol\n"
            "- URLs: Display URLs as-is, no markdown formatting.\n"
            "- Subject lines: Under 60 characters\n"
            "- Include formal greetings/closings"
        ),

        "sms": (
            "Structure SMS messages with:\n"
            "- No special formatting symbols\n"
            "- URLs: Shorten when possible\n"
            "- Length: Maximum 160 characters\n"
            "- Line breaks: Use basic separation\n"
            "- Avoid emojis unless requested"
        ),

        "default": (
            "Use default formatting rules:\n"
            "- Italic: Wrap text with underscores (_text_)\n"
            "- Bold: Wrap text with asterisks (*text*)\n"
            "- Strikethrough: Wrap text with tildes (~text~)\n"
            "- URLs: Reformat all URLs to use markdown ([link text or filename](url)).\n"
            "- Separate paragraphs with line breaks"
        )
    };
    has prompt: str = """
    ## **Objective**
    Analyze the provided `UTTERANCE`, `RESPONSE`, and `CONTEXT` to identify and format relevant references from `CONTEXT` that support the `RESPONSE`.

    ## **Instructions**
    1. **Reference Identification**:
    - Match key information in `RESPONSE` with supporting evidence in `CONTEXT`
    - Use fields specified in `REF_FIELDS` to extract reference details
    - Ensure references directly support claims made in the response

    2. **Reference Formatting**:
    - Apply the structure defined in `REF_PATTERN`
    - Follow `CHANNEL_FORMAT` rules for URLs and text styling
    - Create a bulleted list of references with proper spacing

    3. **Output Requirements**:
    - Begin with "Read more here:" **translated into the language of RESPONSE**.
    - Format as valid JSON with single key "references"
    - Return empty string "" if no relevant references found'
    - Exclude markdown and JSON delimiters
    - Include only formatted references, no additional text

    4. **Output Review**:
    - When multiple reference list items have the same source/filename but different pages, combine them into a single entry (e.g., "Book Title, pg. 1, 2, 3")
    - Response must be a valid JSON object containing only the "references" key and formatted reference string.

    UTTERANCE:
    {utterance}

    RESPONSE:
    {response}

    CONTEXT:
    {context}

    REF_FIELDS:
    {ref_fields}

    REF_PATTERN:
    {ref_pattern}

    CHANNEL_FORMAT:
    {channel_format}

    """;

    has response_template:str = """
{response}

{references}
""";

    # the field or fields (comma separated) in the metadata to use for crafting the references
    has metadata_ref_fields:str = "filename, source, page";
    # an example format used for formatting the references based on the metadata_ref_fields
    has metadata_ref_format:str = "<source>, pg. <page>";

    def post_register() {
        # to ensure compatibility, add this action to the exception list in intent_classifier
        if(intent_interact_action_node := self.get_agent().get_action(action_label='IntentInteractAction')) {
            if(self.get_type() not in intent_interact_action_node.exceptions) {
                intent_interact_action_node.exceptions += [self.get_type()];
            }
        }
        self.get_agent().get_actions() spawn _configure_retrieval_action(self.retrieval_interact_action);
    }

    def touch(visitor: agent_graph_walker) -> bool {
        response_context = visitor.interaction_node.data_get(self.retrieval_interact_action, {});
        if(visitor.interaction_node.has_response() and response_context) {
            return True;
        }
    }

    def on_enable() {
        self.get_agent().get_actions() spawn _configure_retrieval_action(self.retrieval_interact_action);
    }

    def execute(visitor: agent_graph_walker) -> None {
        retrieval_context = visitor.interaction_node.data_get(self.retrieval_interact_action, {});

        utterance = retrieval_context.get('query', '');
        response_context = retrieval_context.get('context', []);
        response = visitor.interaction_node.response.get('message', {}).get('content', '');

        try {
            if (utterance and response_context) {
                if "metadata" in response_context[0] {
                    prompt_messages = [{"system": self.prompt}];
                    prompt_variables = {
                        "ref_fields": self.metadata_ref_fields,
                        "ref_pattern": self.metadata_ref_format,
                        "context": response_context,
                        "response": response,
                        "utterance": utterance,
                        "channel_format": self.get_channel_format_directive(visitor=visitor)
                    };

                    model_action = self.get_agent().get_action(action_label=self.model_action);
                    if model_action {
                        model_action_result = model_action.call_model(
                            prompt_messages=prompt_messages,
                            prompt_variables=prompt_variables,
                            model_name = self.model_name,
                            model_temperature = self.model_temperature,
                            model_max_tokens = self.model_max_tokens,
                            interaction_node=visitor.interaction_node
                        );

                        if model_action_result {
                            result = model_action_result.get_json_result();
                            if (references := result.get("references")) {
                                response = self.response_template.format(response=response, references=references);
                                interaction_message = visitor.interaction_node.get_message();
                                if not interaction_message {
                                    interaction_message = TextInteractionMessage(content=response);
                                } else {
                                    interaction_message.content = response;
                                }
                                visitor.interaction_node.set_message(interaction_message);
                            }
                        }
                    }
                }
            }
        } except Exception as e {
            self.logger.warning("Unable to add references to response");
        }
    }

    def get_channel_format_directive(visitor: agent_graph_walker) -> dict {
        channel = visitor.interaction_node.channel or "default";
        return self.channel_format_directives.get(channel, None);
    }

    def healthcheck() -> Union[bool, dict] {

        

        try {
            if (not self.metadata_ref_fields) {
                return {
                    "status": False,
                    "message": "Missing required metadata_ref_fields",
                    "severity": "error"
                };
            }
            if (not self.metadata_ref_format) {
                return {
                    "status": False,
                    "message": "Missing required metadata_ref_format",
                    "severity": "error"
                };
            }
            if (not self.channel_format_directives) {
                return {
                    "status": False,
                    "message": "Missing required channel_format_directives",
                    "severity": "error"
                };
            }

            if (not self.model_name) {
                return {
                    "status": False,
                    "message": "Missing required model_name",
                    "severity": "error"
                };
            }

            if (not self.prompt) {
                return {
                    "status": False,
                    "message": "Missing required prompt",
                    "severity": "error"
                };
            }

            if (not self.retrieval_interact_action) {
                return {
                    "status": False,
                    "message": "Missing required retrieval_interact_action",
                    "severity": "error"
                };
            }

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

    has retrieval_interact_action: str = "";

    obj __specs__ {
        static has private: bool = True;
    }

    can on_actions with Actions entry {
        visit [-->](`?RetrievalInteractAction)(?label==self.retrieval_interact_action)(?enabled==True);
    }

    can on_action with RetrievalInteractAction entry {
        here.metadata = True;
    }

}