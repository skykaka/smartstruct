// Sometimes we need to pass some variable to the static function just like "this pointer".
// We can use the named parameters to implement the goal.
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';
import 'package:smartstruct_generator/models/source_assignment.dart';


Expression invokeNestedMappingForStaticFunction(
  ExecutableElement sourceFunction,
  ClassElement abstractMapper,
  VariableElement targetField,
  Expression sourceFieldAssignment,
) {
  final returnType = sourceFunction.returnType;
  final matchingMappingMethods = findMatchingMappingMethod(
      abstractMapper, targetField.type, returnType);
  if(matchingMappingMethods.isNotEmpty) {
    final nestedMappingMethod = matchingMappingMethods.first;

    if(
      nestedMappingMethod.parameters.first.type.nullabilitySuffix != NullabilitySuffix.question &&
      sourceFunction.returnType.nullabilitySuffix == NullabilitySuffix.question
    ) {
      final str = makeNullCheckCall(
        sourceFieldAssignment.accept(
          DartEmitter()
        ).toString(),
        nestedMappingMethod,
      );
      sourceFieldAssignment = refer(str);
    } else {
      sourceFieldAssignment = refer(matchingMappingMethods.first.name)
          .call([sourceFieldAssignment]);
    }
  }
  return sourceFieldAssignment;
}

/// Finds a matching Mapping Method in [classElement]
/// which has the same return type as the given [targetReturnType] and same parametertype as the given [sourceParameterType]
Iterable<MethodElement> findMatchingMappingMethod(ClassElement classElement,
    DartType targetReturnType, DartType sourceParameterType) {
  final matchingMappingMethods = classElement.methods.where((met) {
    // Sometimes the user is troubled by the nullability of these types.
    // So ingore the nullability of all the type for the nested mapping function is more easy to be matched.
    // The process of nullability is one duty for this library.

    if(met.parameters.isEmpty) {
        return false;
    }
    final metReturnElement = met.returnType.element;
    final metParameterElement = met.parameters.first.type.element;

    final targetReturnElement = targetReturnType.element;
    final srcParameterElement = sourceParameterType.element;

    return metReturnElement == targetReturnElement &&
        (metParameterElement == srcParameterElement);

    // return met.returnType == targetReturnType &&
    //     met.parameters.isNotEmpty && met.parameters.first.type == sourceParameterType;
  });
  return matchingMappingMethods;
}

makeNullCheckCall(
  String checkTarget,
  MethodElement method,
) {

  final methodInvoke = refer(method.name).call([refer("tmp")]).accept(DartEmitter()).toString();
  return '''
  (){
    final tmp = $checkTarget;
    return tmp == null ? null : $methodInvoke;
  }()
''';
}

Expression invokeNestedMappingFunction(
  MethodElement method, 
  bool sourceNullable,
  Expression refWithQuestion,
  Expression ref,
) {
  Expression sourceFieldAssignment;
  if(method.parameters.first.isOptional) {
    // The parameter can be null.
    sourceFieldAssignment = refer(method.name)
        .call([refWithQuestion]);
  } else {
    sourceFieldAssignment = refer(method.name)
        .call([ref]);
    sourceFieldAssignment = checkNullExpression(
      sourceNullable,
      refWithQuestion, 
      sourceFieldAssignment
    );
  }
  return sourceFieldAssignment;
}

Expression checkNullExpression(
  bool needCheck,
  Expression sourceRef,
  Expression expression,
) {
  if(needCheck) {
    return sourceRef.equalTo(literalNull).conditional(
      literalNull, 
      expression,
    );
  } else {
    return expression;
  }
}

